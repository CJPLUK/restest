package restest_apidiff.deps

import std.env.*
import stdx.encoding.json.*
import toml4cj.decoders.*

public class ConfigMissingKeyException <: Exception {
    public init(key: String) {
        super("restest.toml is missing required key '${key}'")
    }

    protected override func getClassName(): String {
        return "ConfigMissingKeyException"
    }
}

public class ConfigTypeException <: Exception {
    public init(key: String, expected: String) {
        super("restest.toml key '${key}' must be ${expected}")
    }

    protected override func getClassName(): String {
        return "ConfigTypeException"
    }
}

public class ConfigFileException <: Exception {
    public init(path: String, reason: String) {
        super("failed to load config file '${path}': ${reason}")
    }

    protected override func getClassName(): String {
        return "ConfigFileException"
    }
}

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
    public RestestConfig(public let leftProjectPath: String, public let rightProjectPath: String) {}
}

func requireValue(value: ?JsonValue, key: String): JsonValue {
    match (value) {
        case Some(jsonValue) => jsonValue
        case None => throw ConfigMissingKeyException(key)
    }
}

func requireString(value: JsonValue, key: String): String {
    match (value) {
        case stringValue: JsonString => stringValue.getValue()
        case _ => throw ConfigTypeException(key, "a string")
    }
}

func loadRestestConfigFromFile(path: String): RestestConfig {
    let decoder = Decoder()
    let root = try {
        decoder.load(path)
        decoder.decode()
    } catch (e: IllegalArgumentException) {
        throw ConfigFileException(path, e.message)
    } catch (e: TomlBaseException) {
        throw ConfigFileException(path, e.message)
    } catch (e: Exception) {
        throw ConfigFileException(path, e.message)
    }
    RestestConfig(
        requireString(requireValue(root.get("left_project"), "left_project"), "left_project"),
        requireString(requireValue(root.get("right_project"), "right_project"), "right_project")
    )
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
    match (getVariable("RESTEST_CONFIG")) {
        case Some(path) => loadRestestConfigFromFile(path)
        case None => loadRestestConfigFromEnv()
    }
}
