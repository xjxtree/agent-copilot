extern void SkillsCopilotRunNativeModelTests(void);

__attribute__((constructor))
static void run_native_model_tests(void) {
    SkillsCopilotRunNativeModelTests();
}

