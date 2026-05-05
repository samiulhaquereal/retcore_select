import 'package:retcore_select/src/config/import.dart';

class RetCoreSelectDefaultTheme {
  /// Creates a default theme that adapts to the provided [BuildContext].
  static RetCoreSelectTheme of(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return RetCoreSelectTheme(
      // --- Field & Label ---
      labelStyle: textTheme.bodyLarge,
      requiredTextStyle: textTheme.bodyLarge?.copyWith(
        color: colorScheme.error,
      ),
      valueStyle: textTheme.titleMedium,
      placeholderStyle: textTheme.titleMedium?.copyWith(
        color: colorScheme.onSurface.withAlpha(128), // 50% opacity
      ),

      // --- Main Field Container ---
      fieldDisabledColor: colorScheme.onSurface.withAlpha(30), // 12% opacity
      fieldBorderRadius: BorderRadius.circular(AppSizes.inputFieldRadius),

      // --- Chips ---
      chipBackgroundColor: colorScheme.secondaryContainer,
      chipLabelStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onSecondaryContainer,
      ),
      chipDeleteIconColor: colorScheme.onSecondaryContainer.withAlpha(
        178,
      ), // 70% opacity
      chipPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      chipShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: colorScheme.outline.withAlpha(128),
        ), // 50% opacity
      ),

      // --- Dropdown ---
      dropdownItemSelectedColor: colorScheme.primary.withAlpha(
        26,
      ), // 10% opacity
      dropdownItemHoverColor: colorScheme.primary.withAlpha(
        20,
      ), // ~8% opacity
      dropdownItemStyle: textTheme.bodyMedium,
      dropdownSelectedItemStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.primary,
      ),

      // --- Separator ---
      separatorColor: colorScheme.outline.withAlpha(100),

      // --- Icons ---
      checkIconTheme: IconThemeData(color: colorScheme.primary, size: 20),
      clearIconTheme: IconThemeData(
        color: colorScheme.onSurface.withAlpha(153), // 60% opacity
        size: 18,
      ),
      dropdownArrowSize: 24.0,
      dropdownArrowEnabledColor: colorScheme.onSurface.withAlpha(
        153,
      ), // 60% opacity
      dropdownArrowDisabledColor: colorScheme.onSurface.withAlpha(
        77,
      ), // 30% opacity
      // --- Search ---
      searchHintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface.withAlpha(128), // 50% opacity
      ),
      searchIconTheme: IconThemeData(
        color: colorScheme.onSurface.withAlpha(153), // 60% opacity
        size: 20.0,
      ),

      // --- Indicators ---
      loadingIndicatorColor: colorScheme.primary,
      loadingTextStyle: textTheme.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
      ),
      noOptionsFoundTextStyle: textTheme.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
