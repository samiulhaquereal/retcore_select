import 'package:flutter/material.dart';
import 'package:retcore_select/retcore_select.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RetCore Select Example',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const ExampleScreen(),
    );
  }
}

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  String? _singleValue;
  String? _singleCreatableValue;
  List<String> _multiValues = [];
  List<String> _fixedValues = ['Flutter', 'React'];
  List<String> _creatableValues = [];
  List<String> _constrainedValues = [];
  String? _liveErrorValue;
  String? _liveErrorText;

  final List<String> _options = [
    'Flutter',
    'React',
    'Vue',
    'Angular',
    'Svelte',
    'Ember',
    'Backbone',
  ];

  List<String> _singleCreatableOptions = ['Flutter', 'React', 'Vue', 'Angular'];

  List<String> _creatableOptions = ['Flutter', 'React', 'Vue', 'Angular'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RetCore Select Example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───────────────────────────────────────────────────────
                // 1. Single Select (with inline search)
                // ───────────────────────────────────────────────────────
                _sectionTitle('1. Single Select with Inline Search'),
                RetCoreSelect<String>(
                  label: 'Select a framework',
                  options: _options,
                  isSearchable: true,
                  isClearable: true,
                  value: _singleValue,
                  onChanged: (v) => setState(() => _singleValue = v),
                ),

                const SizedBox(height: 32),

                _sectionTitle('2. Single Select - Creatable'),
                RetCoreSelect<String>(
                  label: 'Single selection with create',
                  options: _singleCreatableOptions,
                  isSearchable: true,
                  isClearable: true,
                  isCreatable: true,
                  value: _singleCreatableValue,
                  onChanged: (v) => setState(() => _singleCreatableValue = v),
                  onCreateOption: (label) {
                    setState(() {
                      _singleCreatableOptions.add(label);
                      _singleCreatableValue = label;
                    });
                  },
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    // ───────────────────────────────────────────────────────
                    // 3. Multi-Select (inline search, clearable)
                    // ───────────────────────────────────────────────────────
                    Expanded(
                      child: Column(
                        children: [
                          _sectionTitle('3. Multi-Select with Inline Search'),
                          RetCoreSelect<String>(
                            label: 'Select your favorite frameworks',
                            placeholder: 'Select...',
                            options: _options,
                            isMulti: true,
                            isSearchable: true,
                            isClearable: true,
                            values: _multiValues,
                            onValuesChanged:
                                (v) => setState(() => _multiValues = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 32),

                    // ───────────────────────────────────────────────────────
                    // 3. Fixed Options  (react-select "fixed-options" demo)
                    // ───────────────────────────────────────────────────────
                    Expanded(
                      child: Column(
                        children: [
                          _sectionTitle('3. Fixed Options (Cannot Be Removed)'),
                          Text(
                            '"Flutter" and "React" are pinned — they cannot be cleared.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          RetCoreSelect<String>(
                            label: 'Select frameworks',
                            options: _options,
                            isMulti: true,
                            isSearchable: true,
                            isClearable: true,
                            fixedOptions: const ['Flutter', 'React'],
                            values: _fixedValues,
                            onValuesChanged:
                                (v) => setState(() => _fixedValues = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ───────────────────────────────────────────────────────
                // 4. Creatable (type a new option and press Enter/select)
                // ───────────────────────────────────────────────────────
                _sectionTitle('4. Creatable — Type to Add New Options'),
                RetCoreSelect<String>(
                  label: 'Add your stack',
                  options: _creatableOptions,
                  isMulti: true,
                  isSearchable: true,
                  isClearable: true,
                  isCreatable: true,
                  values: _creatableValues,
                  onValuesChanged: (v) => setState(() => _creatableValues = v),
                  onCreateOption: (label) {
                    setState(() {
                      _creatableOptions.add(label);
                      _creatableValues.add(label);
                    });
                  },
                ),

                const SizedBox(height: 32),

                // ───────────────────────────────────────────────────────
                // 5. Disabled State
                // ───────────────────────────────────────────────────────
                _sectionTitle('5. Disabled State'),
                RetCoreSelect<String>(
                  label: 'Disabled field',
                  isDisabled: true,
                  options: _options,
                  isMulti: true,
                  fixedOptions: const ['Flutter', 'React'],
                  values: const ['Flutter', 'React'],
                  onValuesChanged: (v) {},
                ),

                const SizedBox(height: 32),

                // ───────────────────────────────────────────────────────
                // 6. Constraints (maxSelectedItems and searchMaxLength)
                // ───────────────────────────────────────────────────────
                _sectionTitle('6. Constraints (Max Items & Max Length)'),
                RetCoreSelect<String>(
                  label: 'Select up to 3 frameworks (max 10 chars search)',
                  options: _options,
                  isMulti: true,
                  isSearchable: true,
                  isClearable: true,
                  maxSelectedItems: 3,
                  searchMaxLength: 10,
                  values: _constrainedValues,
                  onValuesChanged: (v) => setState(() => _constrainedValues = v),
                ),

                const SizedBox(height: 32),

                // ───────────────────────────────────────────────────────
                // 7. Live Validation (Error Message)
                // ───────────────────────────────────────────────────────
                _sectionTitle('7. Live Validation (No Special Characters)'),
                RetCoreSelect<String>(
                  label: 'Type a new framework (alphabets only)',
                  options: const ['Flutter', 'React'],
                  isSearchable: true,
                  isCreatable: _liveErrorText == null, // If there's an error, don't allow creating
                  isClearable: true,
                  value: _liveErrorValue,
                  errorText: _liveErrorText,
                  onSearch: (query) {
                    // Check for special characters using Regex
                    if (query.isNotEmpty && !RegExp(r'^[a-zA-Z\s]+$').hasMatch(query)) {
                      setState(() {
                        _liveErrorText = 'Special characters and numbers are not allowed!';
                      });
                    } else if (query.length >= 10) {
                      setState(() {
                        _liveErrorText = 'Max length reached (10)!';
                      });
                    } else {
                      setState(() {
                        _liveErrorText = null;
                      });
                    }
                  },
                  onChanged: (v) => setState(() => _liveErrorValue = v),
                  onCreateOption: (v) => setState(() {
                     _liveErrorValue = v;
                     _liveErrorText = null;
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
