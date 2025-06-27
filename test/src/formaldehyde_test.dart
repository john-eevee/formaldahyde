import 'package:formaldehyde/formaldehyde.dart'; // Assuming your package structure
import 'package:test/test.dart';

// --- Helper Enums and Classes for Testing ---
enum TestFormKeys {
  name,
  email,
  age,
  price,
  middleName,
  optionalScore,
  optionalMeasurement,
  customField,
  fieldWithDefault,
  anotherField,
}

class MinLengthError extends ValidationError<TestFormKeys> {
  const MinLengthError({required super.field, required this.minLength});

  final int minLength;

  @override
  String printable() =>
      '${field.toString().split('.').last} must be at least $minLength characters.';

  @override
  List<Object?> get props => [super.field, minLength];
}

class MaxLengthError extends ValidationError<TestFormKeys> {
  const MaxLengthError({required super.field, required this.maxLength});

  final int maxLength;

  @override
  String printable() =>
      '${field.toString().split('.').last} must be at most $maxLength characters.';

  @override
  List<Object?> get props => [super.field, maxLength];
}

class InvalidEmailError extends ValidationError<TestFormKeys> {
  const InvalidEmailError({required super.field});

  @override
  String printable() =>
      'Invalid email format for ${field.toString().split('.').last}.';

  @override
  // TODO: implement props
  List<Object?> get props => [super.field];
}

class MustBePositiveError extends ValidationError<TestFormKeys> {
  const MustBePositiveError({required super.field});

  @override
  String printable() => '${field.toString().split('.').last} must be positive.';

  @override
  // TODO: implement props
  List<Object?> get props => [super.field];
}

// --- Test Validators ---
Future<Set<ValidationError<TestFormKeys>>> validateMinLength(
  String? value,
  Form<TestFormKeys> form,
  TestFormKeys field,
  int length,
) async {
  if (value != null && value.length < length) {
    return {MinLengthError(field: field, minLength: length)};
  }
  return {};
}

Future<Set<ValidationError<TestFormKeys>>> validateMaxLength(
  String? value,
  Form<TestFormKeys> form,
  TestFormKeys field,
  int length,
) async {
  if (value != null && value.length > length) {
    return {MaxLengthError(field: field, maxLength: length)};
  }
  return {};
}

Future<Set<ValidationError<TestFormKeys>>> validateEmail(
  String? value,
  Form<TestFormKeys> form,
) async {
  if (value != null && !value.contains('@')) {
    return {const InvalidEmailError(field: TestFormKeys.email)};
  }
  return {};
}

Future<Set<ValidationError<TestFormKeys>>> validatePositiveInt(
  int? value,
  Form<TestFormKeys> form,
  TestFormKeys field,
) async {
  if (value != null && value <= 0) {
    return {MustBePositiveError(field: field)};
  }
  return {};
}

Future<Set<ValidationError<TestFormKeys>>> validatePositiveDouble(
  double? value,
  Form<TestFormKeys> form,
  TestFormKeys field,
) async {
  if (value != null && value <= 0) {
    return {MustBePositiveError(field: field)};
  }
  return {};
}

void main() {
  group('ValidationError', () {
    test('IsRequired printable', () {
      final error = IsRequired(field: TestFormKeys.name);
      expect(error.printable(), 'name is required.');
      expect(error.toString(), 'name is required.');
    });

    test('GenericParsingError printable', () {
      const error =
          GenericParsingError(field: TestFormKeys.age, cause: 'Not a number');
      expect(error.printable(), 'Invalid format for age: Not a number');
      expect(error.toString(), 'Invalid format for age: Not a number');
    });

    test('Custom ValidationError printable', () {
      const error = MinLengthError(field: TestFormKeys.name, minLength: 5);
      expect(error.printable(), 'name must be at least 5 characters.');
    });

    test('fieldName getter', () {
      final error = IsRequired(field: TestFormKeys.middleName);
      expect(error.fieldName, 'middleName');
    });
  });

  group('FieldDefinition', () {
    // --- Raw Constructor ---
    group('.raw()', () {
      test('creates a field definition', () {
        final field = FieldDefinitionifinition.raw(
          name: TestFormKeys.customField,
          isRequired: true,
          defaultValue: () => 'default',
          parser: (dynamic val) => val.toString(),
          validator: (value, form) async => {},
        );
        expect(field.name, TestFormKeys.customField);
        expect(field.isRequired, isTrue);
        expect(field.defaultValue!(), 'default');
        expect(field.parser('test'), 'test');
        expect(field.validator, isNotNull);
      });
    });

    // --- String Factory ---
    group('.string()', () {
      test('creates a string field', () {
        final field = FieldDefinitionifinition.string<TestFormKeys>(
          name: TestFormKeys.name,
          isRequired: true,
          defaultValue: () => 'Default Name',
          validator: (val, form) =>
              validateMinLength(val, form, TestFormKeys.name, 3),
        );
        expect(field.name, TestFormKeys.name);
        expect(field.isRequired, isTrue);
        expect(field.parser('  test  '), 'test');
        expect(field.parser(null), 'Default Name');
        expect(field.parser(123), '123');
        expect(field.defaultValue!(), 'Default Name');
      });

      test('parser trims whitespace', () {
        final field = FieldDefinitionifinition.string<TestFormKeys>(
            name: TestFormKeys.name);
        expect(field.parser('  hello world  '), 'hello world');
        expect(field.parser('  '), '');
      });

      test('parser handles null input for non-nullable string', () {
        final field = FieldDefinitionifinition.string<TestFormKeys>(
            name: TestFormKeys.name);
        expect(
          field.parser(null),
          '',
        ); // Default behavior for non-nullable string
      });

      test(
          'parser handles null input with defaultValue for non-nullable string',
          () {
        final field = FieldDefinitionifinition.string<TestFormKeys>(
          name: TestFormKeys.name,
          defaultValue: () => "def",
        );
        expect(field.parser(null), 'def');
      });
    });

    // --- Integer Factory ---
    group('.integer()', () {
      test('creates an integer field', () {
        final field = FieldDefinitionifinition.integer<TestFormKeys>(
          name: TestFormKeys.age,
          isRequired: false,
          defaultValue: () => 18,
          validator: (val, form) =>
              validatePositiveInt(val, form, TestFormKeys.age),
        );
        expect(field.name, TestFormKeys.age);
        expect(field.isRequired, isFalse);
        expect(field.parser('  25  '), 25);
        expect(field.parser(30), 30);
        expect(field.defaultValue!(), 18);
      });

      test('parser throws FormatException for invalid int', () {
        final field = FieldDefinitionifinition.integer<TestFormKeys>(
            name: TestFormKeys.age);
        expect(() => field.parser('abc'), throwsA(isA<FormatException>()));
        expect(() => field.parser('12.34'), throwsA(isA<FormatException>()));
      });

      test('parser uses defaultValue if parsing fails and default is provided',
          () {
        final field = FieldDefinitionifinition.integer<TestFormKeys>(
          name: TestFormKeys.age,
          defaultValue: () => 0,
        );
        expect(field.parser('abc'), 0);
      });

      test(
          'parser throws FormatException for null when no default and non-nullable',
          () {
        final field = FieldDefinitionifinition.integer<TestFormKeys>(
            name: TestFormKeys.age);
        expect(() => field.parser(null), throwsA(isA<FormatException>()));
      });
    });

    // --- FloatPoint (Double) Factory ---
    group('.floatPoint()', () {
      test('creates a double field', () {
        final field = FieldDefinitionifinition.floatPoint<TestFormKeys>(
          name: TestFormKeys.price,
          isRequired: true,
          validator: (val, form) =>
              validatePositiveDouble(val, form, TestFormKeys.price),
        );
        expect(field.name, TestFormKeys.price);
        expect(field.isRequired, isTrue);
        expect(field.parser('  3.14  '), 3.14);
        expect(field.parser(2.718), 2.718);
        expect(field.parser('10'), 10.0);
      });

      test('parser throws FormatException for invalid double', () {
        final field = FieldDefinitionifinition.floatPoint<TestFormKeys>(
            name: TestFormKeys.price);
        expect(() => field.parser('abc'), throwsA(isA<FormatException>()));
        expect(
          () => field.parser('3,14'),
          throwsA(isA<FormatException>()),
        ); // Comma as decimal separator
      });

      test('parser uses defaultValue if parsing fails and default is provided',
          () {
        final field = FieldDefinitionifinition.floatPoint<TestFormKeys>(
          name: TestFormKeys.price,
          defaultValue: () => 0.0,
        );
        expect(field.parser('abc'), 0.0);
      });

      test(
          'parser throws FormatException for null when no default and non-nullable',
          () {
        final field = FieldDefinitionifinition.floatPoint<TestFormKeys>(
            name: TestFormKeys.price);
        expect(() => field.parser(null), throwsA(isA<FormatException>()));
      });
    });

    // --- NullableString Factory ---
    group('.nullableString()', () {
      test('creates a nullable string field', () {
        final field = FieldDefinitionifinition.nullableString<TestFormKeys>(
          name: TestFormKeys.middleName,
          validator: (val, form) =>
              validateMaxLength(val, form, TestFormKeys.middleName, 10),
        );
        expect(field.name, TestFormKeys.middleName);
        expect(field.isRequired, isFalse); // Default for nullable
        expect(field.parser('  test  '), 'test');
        expect(field.parser(null), isNull);
        expect(field.parser(''), ''); // Empty string is not null
        expect(field.defaultValue!(), isNull);
      });
    });

    // --- NullableInteger Factory ---
    group('.nullableInteger()', () {
      test('creates a nullable integer field', () {
        final field = FieldDefinitionifinition.nullableInteger<TestFormKeys>(
          name: TestFormKeys.optionalScore,
        );
        expect(field.name, TestFormKeys.optionalScore);
        expect(field.parser('  100  '), 100);
        expect(field.parser(null), isNull);
        expect(field.parser(''), isNull); // Empty string parsed as null
        expect(field.parser('abc'), isNull); // Invalid format parsed as null
        expect(field.defaultValue!(), isNull);
      });
    });

    // --- NullableDouble Factory ---
    group('.nullableDouble()', () {
      test('creates a nullable double field', () {
        final field = FieldDefinitionifinition.nullableDouble<TestFormKeys>(
          name: TestFormKeys.optionalMeasurement,
        );
        expect(field.name, TestFormKeys.optionalMeasurement);
        expect(field.parser('  99.9  '), 99.9);
        expect(field.parser(null), isNull);
        expect(field.parser(''), isNull); // Empty string parsed as null
        expect(field.parser('xyz'), isNull); // Invalid format parsed as null
        expect(field.defaultValue!(), isNull);
      });
    });

    // --- Validate Method ---
    group('.validate()', () {
      final nameFieldRequired = FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.name,
        isRequired: true,
      );
      final ageFieldOptional = FieldDefinitionifinition.integer<TestFormKeys>(
        name: TestFormKeys.age,
        isRequired: false,
      );
      final emailFieldWithValidator =
          FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.email,
        validator: validateEmail,
      );
      FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.fieldWithDefault,
        defaultValue: () => "default_val",
        isRequired:
            false, // Can be true or false, default value takes precedence if change is null
      );
      final requiredFieldWithDefault =
          FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.fieldWithDefault,
        defaultValue: () => "default_val",
        isRequired: true,
      );

      test(
          'returns IsRequired error if required and change is null and no default',
          () async {
        final form = Form(fields: {nameFieldRequired});
        final errors = await nameFieldRequired.validate(null, form);
        expect(errors, isNotEmpty);
        expect(errors.first, isA<IsRequired>());
        expect((errors.first as IsRequired).field, TestFormKeys.name);
      });

      test(
          'returns no error if required, change is null, but defaultValue is provided',
          () async {
        final form = Form(fields: {requiredFieldWithDefault});
        final errors = await requiredFieldWithDefault.validate(null, form);
        expect(errors, isEmpty);
      });

      test('returns no error if not required and change is null', () async {
        final form = Form(fields: {ageFieldOptional});
        final errors = await ageFieldOptional.validate(null, form);
        expect(errors, isEmpty);
      });

      test('returns validator errors if validator fails', () async {
        final form = Form(fields: {emailFieldWithValidator});
        final errors =
            await emailFieldWithValidator.validate('invalid-email', form);
        expect(errors, isNotEmpty);
        expect(errors.first, isA<InvalidEmailError>());
      });

      test('returns no errors if validator passes', () async {
        final form = Form(fields: {emailFieldWithValidator});
        final errors = await emailFieldWithValidator.validate(
          'valid@email.com',
          form,
        );
        expect(errors, isEmpty);
      });

      test('uses defaultValue for validation if change is null', () async {
        // Validator expects a non-null string that is not "default_val" to fail
        failingValidator(String? val, Form<TestFormKeys> form) async {
          if (val != null && val == "default_val") {
            return <ValidationError<TestFormKeys>>{};
          }
          return {
            const MinLengthError(
              field: TestFormKeys.fieldWithDefault,
              minLength: 100,
            ),
          };
        }

        final field = FieldDefinitionifinition.string<TestFormKeys>(
          name: TestFormKeys.fieldWithDefault,
          defaultValue: () => "default_val",
          validator: failingValidator,
        );
        final form = Form(fields: {field});
        final errors = await field.validate(
          null,
          form,
        ); // change is null, defaultValue will be used
        expect(errors, isEmpty);

        final errorsWithChange = await field.validate("other_value", form);
        expect(errorsWithChange, isNotEmpty);
        expect(errorsWithChange.first, isA<MinLengthError>());
      });

      test('validator receives parsed value', () async {
        bool validatorCalledWithCorrectType = false;
        final field = FieldDefinitionifinition.integer<TestFormKeys>(
          name: TestFormKeys.age,
          validator: (int? value, Form<TestFormKeys> form) async {
            if (value == 25) {
              // The string '25' should be parsed to int 25
              validatorCalledWithCorrectType = true;
            }
            return {};
          },
        );
        final form = Form(fields: {field});
        await field.validate('25', form);
        expect(validatorCalledWithCorrectType, isTrue);
      });
    });
    // --- toString Method ---
    test('.toString()', () {
      final field1 = FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.name,
        isRequired: true,
      );
      expect(
        field1.toString(),
        'FieldDefinition{name: TestFormKeys.name, isRequired: true, hasDefaultValue: false, hasValidator: false}',
      );

      final field2 = FieldDefinitionifinition.integer<TestFormKeys>(
        name: TestFormKeys.age,
        defaultValue: () => 0,
        validator: (v, f) async => {},
      );
      expect(
        field2.toString(),
        'FieldDefinition{name: TestFormKeys.age, isRequired: false, hasDefaultValue: true, hasValidator: true}',
      );
    });

    // --- Equatable Props ---
    test('props for equality', () {
      final field1 = FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.name,
        isRequired: true,
      );
      final field2 = FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.name,
        isRequired: true,
      );
      final field3 = FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.email,
        isRequired: true,
      );
      final field4 = FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.name,
        isRequired: false,
      );
      final field5 = FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.name,
        isRequired: true,
        defaultValue: () => "a",
      );
      final field6 = FieldDefinitionifinition.string<TestFormKeys>(
        name: TestFormKeys.name,
        isRequired: true,
        defaultValue: () => "a",
      );
      // Note: Validators are functions, so FieldDefinitions with different validator instances won't be equal
      // even if the functions do the same thing. Only name, isRequired, and defaultValue are in props.

      expect(field1 == field2, isTrue);
      expect(field1.hashCode == field2.hashCode, isTrue);
      expect(field1 == field3, isFalse);
      expect(field1 == field4, isFalse);
      expect(
        field5 == field6,
        isTrue,
      ); // Default value functions are compared by reference if not identical. Here they are.
      // For robust equality with functional fields, consider how they are defined or avoid in props.
      // The current implementation compares the function reference for defaultValue.
    });
  });

  group('Form', () {
    final nameField = FieldDefinitionifinition.string<TestFormKeys>(
      name: TestFormKeys.name,
      isRequired: true,
      validator: (v, f) => validateMinLength(v, f, TestFormKeys.name, 2),
    );
    final ageField = FieldDefinitionifinition.integer<TestFormKeys>(
      name: TestFormKeys.age,
      validator: (v, f) => validatePositiveInt(v, f, TestFormKeys.age),
    );
    final emailFieldOptional =
        FieldDefinitionifinition.nullableString<TestFormKeys>(
      name: TestFormKeys.email,
      validator: validateEmail,
    );
    final priceFieldWithDefault =
        FieldDefinitionifinition.floatPoint<TestFormKeys>(
      name: TestFormKeys.price,
      defaultValue: () => 0.0,
      isRequired: false,
    );

    late Form<TestFormKeys> form;

    setUp(() {
      form = Form<TestFormKeys>(
        fields: {
          nameField,
          ageField,
          emailFieldOptional,
          priceFieldWithDefault,
        },
      );
    });

    test('initial state', () {
      expect(
        form.fieldDefinitions,
        {nameField, ageField, emailFieldOptional, priceFieldWithDefault},
      );
      expect(form.changes, isEmpty);
      expect(form.values, isEmpty);
      expect(form.errors, isEmpty);
      expect(form.hasErrors, isFalse);
    });

    test('.addChange() updates changes map', () {
      form = form.addChange(const Change(TestFormKeys.name, 'Jo'));
      expect(form.changes[TestFormKeys.name], 'Jo');
      form = form.addChange(const Change(TestFormKeys.age, 30));
      expect(form.changes[TestFormKeys.age], 30);
      expect(form.values, isEmpty); // Values not updated yet
      expect(form.errors, isEmpty);
    });

    test('addChange dont accept null as value for non-null fields', () {
      expect(
        () => form.addChange(Change(TestFormKeys.age, null)),
        throwsException,
      );
    });

    group('.apply()', () {
      test('successful validation and parsing', () async {
        form = form.addChange(const Change(TestFormKeys.name, 'John Doe'));
        form = form.addChange(const Change(TestFormKeys.age, '30'));
        form = form.addChange(
          const Change(TestFormKeys.email, 'john.doe@example.com'),
        );
        // priceFieldWithDefault is not changed, will use its default

        final appliedForm = await form.apply();

        expect(
          appliedForm.errors,
          isEmpty,
          reason: "Errors found: ${appliedForm.errors}",
        );
        expect(appliedForm.hasErrors, isFalse);
        expect(appliedForm.values[TestFormKeys.name], 'John Doe');
        expect(appliedForm.values[TestFormKeys.age], 30);
        expect(appliedForm.values[TestFormKeys.email], 'john.doe@example.com');
        // Default value for price should be parsed and included if not explicitly changed and no errors
        expect(
          appliedForm.values.containsKey(TestFormKeys.price),
          isTrue,
          reason: "Price field missing from values",
        );
        expect(appliedForm.values[TestFormKeys.price], 0.0); // Default value
        expect(
          appliedForm.changes,
          form.changes,
        ); // Changes should be preserved
      });

      test('validation fails for required field', () async {
        form = form.addChange(
          const Change(TestFormKeys.name, null),
        ); // Name is required
        form = form.addChange(const Change(TestFormKeys.age, '25'));

        final appliedForm = await form.apply();

        expect(appliedForm.errors, isNotEmpty);
        expect(appliedForm.hasErrors, isTrue);
        expect(appliedForm.errors[TestFormKeys.name], isNotNull);
        expect(appliedForm.errors[TestFormKeys.name]!.length, equals(2));
        expect(appliedForm.errors[TestFormKeys.name]!.first, isA<IsRequired>());
        expect(
          appliedForm.values,
          isEmpty,
        ); // Values map should be empty or original if errors
      });

      test('validation fails due to custom validator', () async {
        form =
            form.addChange(const Change(TestFormKeys.name, 'J')); // Too short
        form = form
            .addChange(const Change(TestFormKeys.age, '-5')); // Not positive

        final appliedForm = await form.apply();

        expect(appliedForm.errors, isNotEmpty);
        expect(appliedForm.hasErrors, isTrue);
        expect(
          appliedForm.errors[TestFormKeys.name]!.first,
          isA<MinLengthError>(),
        );
        expect(
          appliedForm.errors[TestFormKeys.age]!.first,
          isA<MustBePositiveError>(),
        );
        expect(appliedForm.values, isEmpty);
      });

      test('parsing error occurs', () async {
        form = form.addChange(const Change(TestFormKeys.name, 'Valid Name'));
        form = form.addChange(const Change(TestFormKeys.age, 'not-a-number'));

        final appliedForm = await form.apply();
        expect(appliedForm.errors, isNotEmpty);
        expect(appliedForm.hasErrors, isTrue);
        expect(
          appliedForm.errors[TestFormKeys.age]!.first,
          isA<GenericParsingError>(),
        );
        expect(
          (appliedForm.errors[TestFormKeys.age]!.first as GenericParsingError)
              .cause,
          contains('FormatException'),
        );
        expect(appliedForm.values, isEmpty);
      });

      test('handles nullable fields correctly (valid null)', () async {
        form = form.addChange(const Change(TestFormKeys.name, 'Some Name'));
        form = form.addChange(const Change(TestFormKeys.age, 10));
        form = form.addChange(
          const Change(TestFormKeys.email, null),
        ); // Valid for nullableString

        final appliedForm = await form.apply();

        expect(
          appliedForm.errors,
          isEmpty,
          reason: "Errors found: ${appliedForm.errors}",
        );
        expect(appliedForm.hasErrors, isFalse);
        expect(appliedForm.values[TestFormKeys.name], 'Some Name');
        expect(appliedForm.values[TestFormKeys.email], isNull);
      });

      test('handles nullable fields correctly (invalid non-null)', () async {
        form = form.addChange(const Change(TestFormKeys.name, 'Some Name'));
        form = form.addChange(const Change(TestFormKeys.email, 'invalidemail'));

        final appliedForm = await form.apply();

        expect(appliedForm.errors, isNotEmpty);
        expect(appliedForm.hasErrors, isTrue);
        expect(
          appliedForm.errors[TestFormKeys.email]!.first,
          isA<InvalidEmailError>(),
        );
      });

      test('apply with no changes returns same form instance', () async {
        final initialForm = Form<TestFormKeys>(fields: {nameField});
        final appliedForm = await initialForm.apply();
        expect(identical(appliedForm, initialForm), isTrue);
      });

      test('apply populates default values if not changed and no errors',
          () async {
        final fieldWithDefaultOnly =
            FieldDefinitionifinition.string<TestFormKeys>(
          name: TestFormKeys.customField,
          defaultValue: () => "my_default",
          isRequired: false,
        );
        final formWithDefault =
            Form<TestFormKeys>(fields: {fieldWithDefaultOnly, nameField});
        var newForm = formWithDefault.addChange(
          const Change(TestFormKeys.name, "Test"),
        ); // Change another field
        newForm = await newForm.apply();

        expect(
          newForm.errors,
          isEmpty,
          reason: "Errors found: ${newForm.errors}",
        );
        expect(newForm.values[TestFormKeys.customField], "my_default");
        expect(newForm.values[TestFormKeys.name], "Test");
      });

      test(
          'any change made will reset values to ensure no stale data after apply',
          () async {
        form =
            form.addChange(const Change(TestFormKeys.name, 'First Valid Name'));
        form = form.addChange(const Change(TestFormKeys.age, '42'));
        var appliedForm = await form.apply();

        expect(appliedForm.errors, isEmpty);
        expect(appliedForm.values[TestFormKeys.name], 'First Valid Name');
        expect(appliedForm.values[TestFormKeys.age], 42);

        // Now make a change that will cause an error
        appliedForm = appliedForm
            .addChange(const Change(TestFormKeys.name, 'X')); // Invalid

        expect(appliedForm.values, isEmpty);
      });

      test('toString() provides useful representation', () {
        form = form.addChange(const Change(TestFormKeys.name, 'Test'));
        final str = form.toString();
        expect(str, contains('Form{'));
        expect(str, contains('fields: {'));
        expect(str, contains('changes: {TestFormKeys.name: Test}'));
        expect(str, contains('values: {}'));
        expect(str, contains('errors: {}'));
      });

      test('props for equality', () async {
        final form1 = Form<TestFormKeys>(fields: {nameField})
            .addChange(const Change(TestFormKeys.name, 'A'));
        final form2 = Form<TestFormKeys>(fields: {nameField})
            .addChange(const Change(TestFormKeys.name, 'A'));
        final form3 = Form<TestFormKeys>(fields: {nameField})
            .addChange(const Change(TestFormKeys.name, 'B'));
        final form4 = Form<TestFormKeys>(fields: {nameField, ageField})
            .addChange(const Change(TestFormKeys.name, 'A'));

        expect(form1 == form2, isTrue);
        expect(form1.hashCode == form2.hashCode, isTrue);
        expect(form1 == form3, isFalse);
        expect(form1 == form4, isFalse);

        final appliedForm1 = await form1.apply();
        final appliedForm2 = await Form<TestFormKeys>(fields: {nameField})
            .addChange(const Change(TestFormKeys.name, 'A'))
            .apply();

        expect(appliedForm2, equals(appliedForm1));
      });
    });
  });

  group('validateMany', () {
    final form = Form<TestFormKeys>(
      fields: {FieldDefinitionifinition.string(name: TestFormKeys.name)},
    ); // Dummy form for validator signature

    Future<Set<ValidationError<TestFormKeys>>> validator1(
      String? val,
      Form<TestFormKeys> f,
    ) async {
      if (val == 'fail1') {
        return {const MinLengthError(field: TestFormKeys.name, minLength: 1)};
      }
      return {};
    }

    Future<Set<ValidationError<TestFormKeys>>> validator2(
      String? val,
      Form<TestFormKeys> f,
    ) async {
      if (val == 'fail2') {
        return {const MaxLengthError(field: TestFormKeys.name, maxLength: 1)};
      }
      return {};
    }

    Future<Set<ValidationError<TestFormKeys>>> validator3(
      String? val,
      Form<TestFormKeys> f,
    ) async {
      if (val == 'fail1') {
        return {
          const InvalidEmailError(field: TestFormKeys.email),
        }; // Different field
      }
      return {};
    }

    test('combines multiple validators, no errors', () async {
      final combined =
          validateMany<String?, TestFormKeys>({validator1, validator2});
      final errors = await combined('pass', form);
      expect(errors, isEmpty);
    });

    test('combines multiple validators, one error', () async {
      final combined =
          validateMany<String?, TestFormKeys>({validator1, validator2});
      final errors = await combined('fail1', form);
      expect(errors, hasLength(1));
      expect(errors.first, isA<MinLengthError>());
    });

    test(
        'combines multiple validators, multiple errors from different validators',
        () async {
      validateMany<String?, TestFormKeys>({validator1, validator2});
      // This scenario is tricky with current setup as one value triggers one or the other.
      // Let's make them trigger on the same input for a better test.
      Future<Set<ValidationError<TestFormKeys>>> validatorA(
        String? val,
        Form<TestFormKeys> f,
      ) async {
        if (val != null && val.length < 5) {
          return {const MinLengthError(field: TestFormKeys.name, minLength: 5)};
        }
        return {};
      }

      Future<Set<ValidationError<TestFormKeys>>> validatorB(
        String? val,
        Form<TestFormKeys> f,
      ) async {
        if (val != null && val.contains('x')) {
          return {
            const InvalidEmailError(field: TestFormKeys.name),
          }; // Using existing error for simplicity
        }
        return {};
      }

      final combined2 =
          validateMany<String?, TestFormKeys>({validatorA, validatorB});
      final errors = await combined2(
        'ax',
        form,
      ); // Fails both: length < 5 and contains 'x'
      expect(errors, hasLength(2));
      expect(errors.whereType<MinLengthError>().length, 1);
      expect(errors.whereType<InvalidEmailError>().length, 1);
    });

    test('combines multiple validators, aggregates errors for same field',
        () async {
      final combined =
          validateMany<String?, TestFormKeys>({validator1, validator3});
      // validator1 -> MinLengthError for name if "fail1"
      // validator3 -> InvalidEmailError for email if "fail1"
      final errors = await combined('fail1', form);
      expect(errors, hasLength(2));
      expect(
        errors.any((e) => e is MinLengthError && e.field == TestFormKeys.name),
        isTrue,
      );
      expect(
        errors.any(
          (e) => e is InvalidEmailError && e.field == TestFormKeys.email,
        ),
        isTrue,
      );
    });

    test('empty set of validators returns no errors', () async {
      final combined = validateMany<String?, TestFormKeys>({});
      final errors = await combined('anyValue', form);
      expect(errors, isEmpty);
    });
  });
}
