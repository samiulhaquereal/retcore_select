import 'package:retcore_select/src/config/import.dart';
export 'src/core/theme/retcore_select_default_theme.dart';
export 'src/core/theme/retcore_select_theme.dart';

/// A highly customizable select widget for Flutter, supporting single and multi-selection,
/// local and API-based searching, and extensive theming.
class RetCoreSelect<T> extends StatelessWidget {
  /// The list of options to display in the dropdown.
  final List<dynamic> options;

  /// The text to display when no value is selected (if no label is provided).
  final String placeholder;

  /// The floating label to display above the field.
  final String? label;

  /// Determines if the widget is in multi-select mode.
  final bool isMulti;

  /// Enables a search bar in the dropdown.
  final bool isSearchable;

  /// Disables the widget.
  final bool isDisabled;

  /// Required Field
  final bool isRequired;

  /// Shows a clear button to deselect all values.
  final bool isClearable;

  /// Configures the widget to fetch options from an API.
  final bool isFromApi;

  /// Shows a loading indicator, typically used with [isFromApi].
  final bool isLoading;

  /// Allows the user to create new options by typing.
  final bool isCreatable;

  /// The theme to style the widget.
  final RetCoreSelectTheme? theme;

  /// A custom builder for creating chip widgets in multi-select mode.
  final CustomChipBuilder<T>? chipBuilder;

  /// A callback that fires when the user types in the search bar.
  final Function(String query)? onSearch;

  /// Called when the user creates a new option (requires [isCreatable] = true).
  final Function(String label)? onCreateOption;

  /// The currently selected value (for single-select mode).
  final T? value;

  /// A callback that fires when the selected value changes (for single-select mode).
  final Function(T?)? onChanged;

  /// The list of currently selected values (for multi-select mode).
  final List<T>? values;

  /// A callback that fires when the selected values change (for multi-select mode).
  final Function(List<T>)? onValuesChanged;

  /// Items that cannot be removed by the user (react-select "fixed" options).
  final List<T> fixedOptions;

  /// Field Validator
  final FormFieldValidator<List<T>>? validator;

  const RetCoreSelect({
    super.key,
    required this.options,
    this.placeholder = 'Select...',
    this.label,
    this.isMulti = false,
    this.isSearchable = false,
    this.isDisabled = false,
    this.isClearable = false,
    this.isFromApi = false,
    this.isLoading = false,
    this.isRequired = false,
    this.isCreatable = false,
    this.theme,
    this.chipBuilder,
    this.onSearch,
    this.onCreateOption,
    this.validator,
    this.value,
    this.onChanged,
    this.values,
    this.onValuesChanged,
    this.fixedOptions = const [],
  }) : assert(
         isMulti
             ? (values != null && onValuesChanged != null)
             : (onChanged != null),
         'For multi-select, `values` and `onValuesChanged` must be provided. For single-select, `onChanged` is required.',
       ),
       assert(
         isMulti
             ? (value == null && onChanged == null)
             : (values == null && onValuesChanged == null),
         'Do not provide single-select properties (`value`, `onChanged`) in multi-select mode, and vice-versa.',
       ),
       assert(
         isFromApi ? onSearch != null : true,
         '`onSearch` callback must be provided when `isFromApi` is true.',
       );

  @override
  Widget build(BuildContext context) {
    return CustomSelectBase<T>(
      placeholder: placeholder,
      label: label,
      isMulti: isMulti,
      validator: validator,
      isRequired: isRequired,
      isSearchable: isSearchable,
      isDisabled: isDisabled,
      isClearable: isClearable,
      isFromApi: isFromApi,
      isLoading: isLoading,
      isCreatable: isCreatable,
      theme: theme ?? RetCoreSelectTheme(),
      chipBuilder: chipBuilder,
      options: options.cast<T>().toList(),
      fixedOptions: fixedOptions.cast<T>().toList(),
      value: isMulti ? values! : (value == null ? [] : [value as T]),
      onChanged: (newValue) {
        if (isMulti) {
          onValuesChanged!(newValue.cast<T>());
        } else {
          onChanged!(newValue.isEmpty ? null : newValue.first as T?);
        }
      },
      onSearch: onSearch,
      onCreateOption: onCreateOption,
    );
  }
}
