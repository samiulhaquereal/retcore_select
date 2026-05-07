import 'package:retcore_select/src/config/import.dart';
import 'package:flutter/scheduler.dart';

// A builder function to create a custom chip widget.
typedef CustomChipBuilder<T> =
    Widget Function(BuildContext context, T value, VoidCallback? onDeleted);

/// The internal stateful widget that powers the CustomSelect.
/// This is not intended to be used directly.
class CustomSelectBase<T> extends StatefulWidget {
  final List<T> options;
  final List<T> value;

  /// Items in this list cannot be removed by the user (react-select "fixed" options).
  final List<T> fixedOptions;

  final String placeholder;
  final String? label;
  final bool isMulti,
      isSearchable,
      isDisabled,
      isClearable,
      isFromApi,
      isLoading,
      isRequired,
      isCreatable;
  final RetCoreSelectTheme theme;
  final CustomChipBuilder<T>? chipBuilder;
  final FormFieldValidator<List<T>>? validator;
  final Function(List<T> newValue) onChanged;
  final Function(String query)? onSearch;

  /// Called when the user creates a new option (only when [isCreatable] is true).
  final Function(String label)? onCreateOption;

  const CustomSelectBase({
    super.key,
    required this.options,
    required this.value,
    this.fixedOptions = const [],
    required this.placeholder,
    this.label,
    required this.isMulti,
    required this.isSearchable,
    required this.isDisabled,
    required this.isClearable,
    required this.isFromApi,
    required this.isLoading,
    required this.isRequired,
    this.isCreatable = false,
    required this.theme,
    this.chipBuilder,
    required this.onChanged,
    this.onSearch,
    this.onCreateOption,
    this.validator,
  });

  @override
  State<CustomSelectBase<T>> createState() => _CustomSelectBaseState<T>();
}

class _CustomSelectBaseState<T> extends State<CustomSelectBase<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey<FormFieldState<List<T>>> _formFieldKey =
      GlobalKey<FormFieldState<List<T>>>();

  // The inline search field embedded in the trigger box
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Debouncer? _debouncer;
  List<T> _filteredOptions = [];
  bool _isOverlayVisible = false;

  // Tracks which dropdown item is hovered (by index)
  int? _hoveredIndex;

  // Used to prevent immediate closing when focus and tap events both trigger
  DateTime? _lastOpenedAt;

  RetCoreSelectTheme get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    if (widget.isFromApi) _debouncer = Debouncer(milliseconds: 500);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    _debouncer?.dispose();
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(CustomSelectBase<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the identifying features of the widget change (like label or selection mode),
    // it's likely a state-swap from a different field in a list (common if keys are missing).
    // In such cases, we should close any active overlay.
    if (widget.label != oldWidget.label || widget.isMulti != oldWidget.isMulti) {
      if (_isOverlayVisible) {
        _hideOverlay();
      }
    }

    if (widget.options != oldWidget.options) {
      if (widget.isFromApi) {
        _filteredOptions = widget.options;
      } else {
        _applyFilter();
      }
    }
    // Sync external value changes with internal FormField state
    if (widget.value != oldWidget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formFieldKey.currentState?.didChange(widget.value);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOverlayVisible) {
        _overlayEntry?.markNeedsBuild();
      }
    });
  }

  void _applyFilter() {
    final query = _searchController.text;
    if (widget.isFromApi) return;
    
    final newFiltered = widget.options
        .where(
          (o) => o.toString().toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    if (mounted) {
      setState(() {
        _filteredOptions = newFiltered;
      });
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      if (!_searchFocusNode.hasFocus && _isOverlayVisible) {
        // Small delay so tap-on-item registers before overlay hides.
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocusNode.hasFocus && _isOverlayVisible) {
            _hideOverlay();
          }
        });
      } else if (_searchFocusNode.hasFocus && !_isOverlayVisible) {
        _showOverlay();
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    _applyFilter();

    if (widget.isFromApi) {
      _debouncer?.run(() {
        if (widget.onSearch != null) widget.onSearch!(query);
      });
    }

    // If creatable/searchable and user is typing, ensure the overlay is open
    if (!_isOverlayVisible && query.isNotEmpty) {
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        _showOverlay();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isOverlayVisible && _searchController.text.isNotEmpty) {
            _showOverlay();
          }
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _overlayEntry?.markNeedsBuild();
    });
  }

  void _toggleOverlay() {
    if (widget.isDisabled) return;
    if (_isOverlayVisible) {
      // If we JUST opened the overlay (e.g. via focus event), ignore the tap
      // to prevent immediate closing.
      if (_lastOpenedAt != null &&
          DateTime.now().difference(_lastOpenedAt!).inMilliseconds < 200) {
        return;
      }
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  /// Determine whether the dropdown should open above or below.
  bool _shouldOpenUpward(RenderBox renderBox, double dropdownHeight) {
    final position = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - position.dy - renderBox.size.height;
    return spaceBelow < dropdownHeight && position.dy > dropdownHeight;
  }

  void _showOverlay() {
    if (_isOverlayVisible) return;
    
    // Safety: ensure any previous entry is cleared before creating a new one
    if (_overlayEntry != null) {
      _removeOverlay();
    }

    _lastOpenedAt = DateTime.now();
    setState(() => _isOverlayVisible = true);

    // Focus the search field after the build so the TextField can catch it.
    if (widget.isSearchable || widget.isCreatable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOverlayVisible) {
          if (!_searchFocusNode.hasFocus) {
            _searchFocusNode.requestFocus();
          }
        }
      });
    }

    final renderBox = context.findRenderObject() as RenderBox;
    if (!renderBox.hasSize) return;
    final size = renderBox.size;
    const dropdownMaxHeight = 250.0;

    final openUpward = _shouldOpenUpward(renderBox, dropdownMaxHeight);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // Background tap-to-close layer
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideOverlay,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            // The dropdown panel
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor:
                  openUpward ? Alignment.topLeft : Alignment.bottomLeft,
              followerAnchor:
                  openUpward ? Alignment.bottomLeft : Alignment.topLeft,
              offset: Offset(
                0.0,
                openUpward ? -4.0 : 4.0,
              ),
              child: Material(
                  elevation: 8.0,
                  borderRadius: BorderRadius.circular(4.0),
                  color:
                      theme.dropdownBackgroundColor ??
                      Theme.of(context).colorScheme.surface,
                  shadowColor: Colors.black26,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width,
                      minWidth: size.width,
                      maxHeight: dropdownMaxHeight,
                    ),
                    child: _buildOptionsList(),
                  ),
                ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    if (!_isOverlayVisible) return;

    // Ensure focus is cleared when overlay is hidden to avoid focus-locking issues
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

    _removeOverlay();
    setState(() {
      _isOverlayVisible = false;
      _hoveredIndex = null;
    });
    _searchController.clear();
    _filteredOptions = widget.options;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onOptionSelected(T option) {
    List<T> newValue;
    if (widget.isMulti) {
      newValue = List.from(widget.value);
      if (newValue.contains(option)) {
        // Don't remove if it's a fixed option
        if (!widget.fixedOptions.contains(option)) {
          newValue.remove(option);
        }
      } else {
        newValue.add(option);
      }
    } else {
      newValue = [option];
      _hideOverlay();
      _searchFocusNode.unfocus();
    }
    _formFieldKey.currentState?.didChange(newValue);
    widget.onChanged(newValue);
    _searchController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _overlayEntry?.markNeedsBuild();
    });
  }

  void _onChipDeleted(T option) {
    // Don't allow deleting fixed options
    if (widget.fixedOptions.contains(option)) return;
    if (widget.isMulti) {
      List<T> newValue = List.from(widget.value);
      newValue.remove(option);
      _formFieldKey.currentState?.didChange(newValue);
      widget.onChanged(newValue);
    }
  }

  void _clearSelection() {
    // Keep fixed options when clearing
    final newValue = List<T>.from(widget.fixedOptions);
    _formFieldKey.currentState?.didChange(newValue);
    widget.onChanged(newValue);
  }

  void _createOption() {
    final label = _searchController.text.trim();
    if (label.isEmpty) return;
    widget.onCreateOption?.call(label);
    _searchController.clear();
    if (!widget.isMulti) {
      // Single-select: close dropdown after creating, just like selecting an option
      _hideOverlay();
      _searchFocusNode.unfocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlayEntry?.markNeedsBuild();
      });
    }
  }

  /// Builds the chips + inline search field inside the trigger box.
  Widget _buildValueDisplay() {
    final bool hasValue = widget.value.isNotEmpty;
    final bool canSearch = widget.isSearchable || widget.isCreatable;

    // --- Single select ---
    if (!widget.isMulti) {
      // When the dropdown is OPEN, always show the search input so the user
      // can type to filter or create — this matches react-select behaviour.
      if (_isOverlayVisible && canSearch) {
        return _buildInlineSearch(
          showPlaceholder: !hasValue,
          // Show the current value as grayed hint so user knows what's selected
          hintText: hasValue ? widget.value.first.toString() : null,
        );
      }
      // Dropdown closed with a value → show the selected text
      if (hasValue) {
        return Text(
          widget.value.first.toString(),
          style: theme.valueStyle,
          overflow: TextOverflow.ellipsis,
        );
      }
      // Dropdown closed, no value, searchable/creatable → show inline search
      if (canSearch) {
        return _buildInlineSearch(showPlaceholder: true);
      }
      // Dropdown closed, no value, not searchable → show placeholder text
      return Text(
        widget.label == null ? widget.placeholder : '',
        style: theme.placeholderStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // --- Multi select ---
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...widget.value.map((option) {
          final bool isFixed = widget.fixedOptions.contains(option);
          onDeleted() => _onChipDeleted(option);
          if (widget.chipBuilder != null) {
            return widget.chipBuilder!(
              context,
              option,
              isFixed ? null : onDeleted,
            );
          }
          return _buildChip(option, isFixed, onDeleted);
        }),
        if (widget.isSearchable)
          _buildInlineSearch(showPlaceholder: !hasValue),
      ],
    );
  }

  Widget _buildChip(T option, bool isFixed, VoidCallback onDeleted) {
    return Container(
      decoration: BoxDecoration(
        color: theme.chipBackgroundColor ?? const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(2.0),
        border: Border.all(
          color:
              isFixed
                  ? Colors.transparent
                  : (theme.chipShape?.side.color ??
                      const Color(0xFFB0C4DE)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(option.toString(), style: theme.chipLabelStyle),
          if (!isFixed) ...[
            const SizedBox(width: 4.0),
            GestureDetector(
              onTap: () {
                onDeleted();
              },
              child: Icon(
                Icons.close,
                size: 12.0,
                color: theme.chipDeleteIconColor ?? const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineSearch({
    required bool showPlaceholder,
    String? hintText, // used in single-select to show current value as hint
  }) {
    final bool canType = !widget.isDisabled && (widget.isSearchable || widget.isCreatable);
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 60, maxWidth: 200),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          enabled: canType,
          readOnly: !canType,
          style: theme.valueStyle ?? const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: hintText ??
                ((showPlaceholder && _searchController.text.isEmpty)
                    ? (widget.label == null ? widget.placeholder : '')
                    : null),
            hintStyle: hintText != null
                // Current-value hint: same style as selected value but lighter
                ? (theme.valueStyle ?? const TextStyle(fontSize: 14))
                    .copyWith(color: (theme.placeholderStyle?.color) ?? Colors.grey)
                : theme.placeholderStyle,
          ),
          onTap: () {
            _toggleOverlay();
          },
        ),
      ),
    );
  }


  Widget _buildOptionsList() {
    final optionsToShow = widget.isFromApi ? widget.options : _filteredOptions;
    final String query = _searchController.text.trim();
    final bool showCreateOption =
        widget.isCreatable &&
        query.isNotEmpty &&
        !optionsToShow.any(
          (o) => o.toString().toLowerCase() == query.toLowerCase(),
        );

    // Loading state
    if (widget.isFromApi && widget.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text('Loading...', style: theme.loadingTextStyle),
        ),
      );
    }

    // Empty — no create option either
    if (optionsToShow.isEmpty && !showCreateOption) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text('No options found.', style: theme.noOptionsFoundTextStyle),
        ),
      );
    }

    // NOTE: We return ListView directly here (no Column+Flexible wrapper).
    // The ConstrainedBox(maxHeight:250) in _showOverlay provides the bounded
    // height that ListView needs to scroll. Flexible inside a mainAxisSize.min
    // Column collapses to zero, which was hiding the list.
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.0),
      child: StatefulBuilder(
        builder: (ctx, setLocalState) {
          final int itemCount =
              optionsToShow.length + (showCreateOption ? 1 : 0);

          return ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              // ── Create option row ──────────────────────────────────────
              if (showCreateOption && index == optionsToShow.length) {
                final bool isHov = _hoveredIndex == -1;
                return MouseRegion(
                  onEnter: (_) => setLocalState(() => _hoveredIndex = -1),
                  onExit: (_) => setLocalState(() => _hoveredIndex = null),
                  child: GestureDetector(
                    onTap: _createOption,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      color: isHov
                          ? (theme.dropdownItemHoverColor ??
                              const Color(0xFFDEEBFF))
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Create "$query"',
                        style: (theme.dropdownItemStyle ??
                                const TextStyle(fontSize: 14))
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                );
              }

              // ── Normal option row ──────────────────────────────────────
              final option = optionsToShow[index];
              final bool isSelected = widget.value.contains(option);
              final bool isHovered = _hoveredIndex == index;

              Color bgColor = Colors.transparent;
              if (isSelected) {
                bgColor = theme.dropdownItemSelectedColor ??
                    const Color(0xFFDEEBFF);
              }
              if (isHovered) {
                bgColor = theme.dropdownItemHoverColor ??
                    const Color(0xFFDEEBFF);
              }

              return MouseRegion(
                onEnter: (_) =>
                    setLocalState(() => _hoveredIndex = index),
                onExit: (_) =>
                    setLocalState(() => _hoveredIndex = null),
                child: GestureDetector(
                  onTap: () => _onOptionSelected(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    color: bgColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.toString(),
                            style: isSelected
                                ? theme.dropdownSelectedItemStyle
                                : theme.dropdownItemStyle,
                          ),
                        ),
                        if (widget.isMulti && isSelected)
                          IconTheme(
                            data: theme.checkIconTheme ??
                                Theme.of(context).iconTheme,
                            child: const Icon(Icons.check),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTrailingIcons() {
    final bool showClear =
        widget.isClearable &&
        widget.value.isNotEmpty &&
        !widget.isDisabled &&
        // Only show clear if there are non-fixed selected items
        widget.value.any((v) => !widget.fixedOptions.contains(v));

    if (widget.isFromApi && widget.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: LoadingVibeIndicator(
          dotSize: widget.theme.loadingIndicatorSize ?? 6,
          dotColor:
              widget.theme.loadingIndicatorColor ?? AppColors.greyColor,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showClear) ...[
          GestureDetector(
            onTap: _clearSelection,
            child: Icon(
              Icons.close,
              size: theme.clearIconTheme?.size ?? 16.0,
              color:
                  theme.clearIconTheme?.color ??
                  AppColors.shade400GrayColor,
            ),
          ),
          const SizedBox(width: 6.0),
          // Vertical separator – matches react-select style
          Container(
            width: 1.0,
            height: 20.0,
            color:
                theme.separatorColor ??
                AppColors.shade300GrayColor ??
                Colors.grey.shade300,
          ),
          const SizedBox(width: 6.0),
        ],
        // Dropdown arrow
        Icon(
          _isOverlayVisible
              ? Icons.keyboard_arrow_up
              : Icons.keyboard_arrow_down,
          size: theme.dropdownArrowSize ?? 20,
          color:
              widget.isDisabled
                  ? (theme.dropdownArrowDisabledColor ??
                      AppColors.shade400GrayColor)
                  : (theme.dropdownArrowEnabledColor ??
                      AppColors.shade600GrayColor),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<List<T>>(
      key: _formFieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      builder: (field) {
        return CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            onTap: _toggleOverlay,
            behavior: HitTestBehavior.opaque,
            child: InputDecorator(
              decoration: (theme.decoration ?? InputDecoration()).copyWith(
                label:
                    widget.label == null
                        ? null
                        : RichText(
                          text: TextSpan(
                            style:
                                theme.labelStyle ??
                                TextStyle(
                                  fontSize: 16,
                                  color:
                                      _isOverlayVisible
                                          ? Theme.of(context).primaryColor
                                          : AppColors.shade600GrayColor,
                                ),
                            children: [
                              TextSpan(text: widget.label),
                              if (widget.isRequired)
                                TextSpan(
                                  text: ' *',
                                  style:
                                      theme.requiredTextStyle ??
                                      TextStyle(
                                        color: AppColors.redColor,
                                        fontSize: 10,
                                      ),
                                ),
                            ],
                          ),
                        ),
                hintText:
                    widget.label != null && !widget.isSearchable
                        ? widget.placeholder
                        : null,
                hintStyle: theme.placeholderStyle,
                labelStyle: theme.labelStyle,
                errorText: field.errorText,
                floatingLabelStyle: theme.floatingLabelStyle,
                filled: widget.isDisabled,
                fillColor:
                    widget.isDisabled ? theme.fieldDisabledColor : null,
                border:
                    theme.decoration?.border ??
                    OutlineInputBorder(
                      borderRadius:
                          widget.theme.fieldBorderRadius ??
                          const BorderRadius.all(Radius.circular(4)),
                    ),
                enabledBorder:
                    theme.decoration?.enabledBorder ??
                    OutlineInputBorder(
                      borderRadius:
                          widget.theme.fieldBorderRadius ??
                          const BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide(
                        color: AppColors.shade300GrayColor ?? Colors.grey,
                      ),
                    ),
                focusedBorder:
                    theme.decoration?.focusedBorder ??
                    OutlineInputBorder(
                      borderRadius:
                          widget.theme.fieldBorderRadius ??
                          const BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2.0,
                      ),
                    ),
                errorBorder:
                    theme.decoration?.errorBorder ??
                    OutlineInputBorder(
                      borderRadius:
                          widget.theme.fieldBorderRadius ??
                          const BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                        width: 1.5,
                      ),
                    ),
                focusedErrorBorder:
                    theme.decoration?.focusedErrorBorder ??
                    OutlineInputBorder(
                      borderRadius:
                          widget.theme.fieldBorderRadius ??
                          const BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                        width: 2.0,
                      ),
                    ),
                contentPadding:
                    theme.decoration?.contentPadding ??
                    const EdgeInsets.fromLTRB(12, 10, 8, 10),
                disabledBorder:
                    theme.decoration?.disabledBorder ??
                    OutlineInputBorder(
                      borderRadius:
                          widget.theme.fieldBorderRadius ??
                          const BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide(
                        color:
                            theme.fieldDisabledColor ??
                            AppColors.shade200GrayColor ??
                            AppColors.greyColor,
                      ),
                    ),
              ),
              isFocused: _isOverlayVisible,
              isEmpty:
                  widget.value.isEmpty &&
                  _searchController.text.isEmpty,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildValueDisplay()),
                  _buildTrailingIcons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
