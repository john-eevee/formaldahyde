import 'package:formaldehyde/src/formaldehyde.dart';
import 'package:test/test.dart';

sealed class SignupFormError extends ValidationError<SignupFormKeys> {
  const SignupFormError({required super.field});

  @override
  List<Object?> get props => [super.field];
}

class FirstNameRequiredError extends SignupFormError {
  const FirstNameRequiredError() : super(field: SignupFormKeys.firstName);
}

class EmailInvalidError extends SignupFormError {
  const EmailInvalidError() : super(field: SignupFormKeys.email);
}

class PasswordMismatchError extends SignupFormError {
  const PasswordMismatchError() : super(field: SignupFormKeys.confirmPassword);
}

class TermsNotAgreedError extends SignupFormError {
  const TermsNotAgreedError() : super(field: SignupFormKeys.agreeToTerms);
}

class PasswordRequirementError extends SignupFormError {
  const PasswordRequirementError() : super(field: SignupFormKeys.password);
}

enum SignupFormKeys {
  firstName,
  lastName,
  email,
  password,
  confirmPassword,
  agreeToTerms,
}

final form = Form<SignupFormKeys>(
  fields: {
    FieldDefinition.string(
      name: SignupFormKeys.firstName,
      isRequired: true,
      validator: (value, _) async {
        if (value.isEmpty) {
          return {const FirstNameRequiredError()};
        }
        return {};
      },
    ),
    FieldDefinition.string(
      name: SignupFormKeys.lastName,
      defaultValue: () => '',
    ),
    FieldDefinition.string(
      name: SignupFormKeys.email,
      isRequired: true,
      validator: (value, _) async {
        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
        if (!emailRegex.hasMatch(value)) {
          return {const EmailInvalidError()};
        }
        return {};
      },
    ),
    FieldDefinition.string(
      name: SignupFormKeys.password,
      isRequired: true,
      validator: (value, _) async {
        if (value.length < 8) {
          return {const PasswordRequirementError()};
        }
        return {};
      },
    ),
    FieldDefinition.string(
      name: SignupFormKeys.confirmPassword,
      isRequired: true,
      validator: (value, form) async {
        final password = form.changeOf<String>(SignupFormKeys.password);
        if (value != password) {
          return {const PasswordMismatchError()};
        }
        return {};
      },
    ),
    FieldDefinition.boolean(
      name: SignupFormKeys.agreeToTerms,
      isRequired: true,
      validator: (value, _) async {
        if (!value) {
          return {const TermsNotAgreedError()};
        }
        return {};
      },
    ),
  },
);

void main() {
  test('password and confirm password must match', () async {
    final filledPasswords = await form
        .addChange(const FieldChange(SignupFormKeys.password, 'password123'))
        .addChange(
          const FieldChange(
            SignupFormKeys.confirmPassword,
            'password123',
          ),
        )
        .apply();
    expect(filledPasswords.errors[SignupFormKeys.confirmPassword], isNull);
  });
}
