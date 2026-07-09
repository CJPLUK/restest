package restest_apidiff.deps

import std.env.*

public class EnvMissingKeyException <: Exception {
    public init(key: String) {
        super("environment variable '${key}' is required")
    }

    protected override func getClassName(): String {
        return "EnvMissingKeyException"
    }
}

public struct RestestConfig {
    public RestestConfig(public let leftProjectPath: String, public let rightProjectPath: String) {}
}

func requireEnvValue(value: ?String, key: String): String {
    match (value) {
        case Some(envValue) => envValue
        case None => throw EnvMissingKeyException(key)
    }
}

func loadRestestConfigFromEnv(): RestestConfig {
    RestestConfig(
        requireEnvValue(getVariable("RESTEST_LEFT_PROJECT"), "RESTEST_LEFT_PROJECT"),
        requireEnvValue(getVariable("RESTEST_RIGHT_PROJECT"), "RESTEST_RIGHT_PROJECT")
    )
}

public func loadRestestConfig(): RestestConfig {
    loadRestestConfigFromEnv()
}
