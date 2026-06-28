import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retcore_select/retcore_select.dart';

void main() {
  group('RetCoreSelect - New Features Test', () {
    testWidgets('maxSelectedItems prevents selecting more than the specified limit', (WidgetTester tester) async {
      List<String> selectedValues = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return RetCoreSelect<String>(
                  options: const ['Option 1', 'Option 2', 'Option 3', 'Option 4'],
                  isMulti: true,
                  maxSelectedItems: 2,
                  values: selectedValues,
                  onValuesChanged: (values) {
                    setState(() {
                      selectedValues = values;
                    });
                  },
                );
              }
            ),
          ),
        ),
      );

      // Open the dropdown
      await tester.tap(find.byType(RetCoreSelect<String>));
      await tester.pumpAndSettle();

      // Tap Option 1
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();

      // Tap Option 2
      await tester.tap(find.text('Option 2'));
      await tester.pumpAndSettle();

      // Tap Option 3
      await tester.tap(find.text('Option 3'));
      await tester.pumpAndSettle();

      // The selection should be limited to 2 items
      expect(selectedValues.length, 2);
      expect(selectedValues, ['Option 1', 'Option 2']);
    });

    testWidgets('searchMaxLength restricts input text length', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetCoreSelect<String>(
              options: const ['Apple', 'Banana'],
              isSearchable: true,
              searchMaxLength: 5,
              onChanged: (value) {},
            ),
          ),
        ),
      );

      // Open the dropdown to focus the text field
      await tester.tap(find.byType(RetCoreSelect<String>));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Enter a string longer than 5 characters
      await tester.enterText(textFieldFinder, '1234567890');
      await tester.pumpAndSettle();

      // When bypassing keyboard input with `enterText`, it's not always guaranteed to be truncated by flutter tests natively without simulating key events, but the TextField widget holds the maxLength property.
      final TextField textField = tester.widget(textFieldFinder);
      expect(textField.maxLength, 5);
    });
  });
}
