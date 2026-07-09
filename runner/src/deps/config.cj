package restest_runner.deps

import std.convert.*
import std.env.*

public class EnvMissingKeyException <: Exception {
    public init(key: String) {
        super("environment variable '${key}' is required")
    }

    protected override func getClassName(): String {
        return "EnvMissingKeyException"
    }
}

public class EnvTypeException <: Exception {
    public init(key: String, expected: String) {
        super("environment variable '${key}' must be ${expected}")
    }

    protected override func getClassName(): String {
        return "EnvTypeException"
    }
}

public struct RestestConfig {
    public RestestConfig(public let commandsPath: String, public let seed: UInt64) {}
}

func requireEnvValue(value: ?String, key: String): String {
    match (value) {
        case Some(envValue) => envValue
        case None => throw EnvMissingKeyException(key)
    }
}

func requireEnvUInt64(value: String, key: String): UInt64 {
    match (UInt64.tryParse(value)) {
        case Some(parsed) => parsed
        case None => throw EnvTypeException(key, "a UInt64")
    }
}

func loadRestestConfigFromEnv(): RestestConfig {
    RestestConfig(
        requireEnvValue(getVariable("RESTEST_COMMANDS"), "RESTEST_COMMANDS"),
        requireEnvUInt64(requireEnvValue(getVariable("RESTEST_SEED"), "RESTEST_SEED"), "RESTEST_SEED")
    )
}

public func loadRestestConfig(): RestestConfig {
    loadRestestConfigFromEnv()
}
