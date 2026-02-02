from data_processor_logging_hook import AuthenticatedLoggingHook

class DummyAuthTokenValidator:
    def is_token_valid(self, user_id):
        # Simulate always valid for test
        return True

def test_logging_hook():
    auth_token_validator = DummyAuthTokenValidator()
    auth_hook = AuthenticatedLoggingHook(auth_token_validator)
    # Sample data
    user_id = 'user123'
    action = 'data_access'
    data = {'field': 'email', 'value': 'example@example.com'}

    result = auth_hook.log(user_id, action, data)
    print('Logging hook result:', result)

if __name__ == '__main__':
    test_logging_hook()
