package restest.deps

import std.convert.*
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

public struct RestestConfig {
    public RestestConfig(public let projectPath: String, public let seed: UInt64) {}
}

public func getRestestConfigPath(): String {
    match (getVariable("RESTEST_CONFIG")) {
        case Some(path) => path
        case None => "restest.toml"
    }
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

func requireUInt64(value: JsonValue, key: String): UInt64 {
    match (value) {
        case intValue: JsonInt =>
            let seed = intValue.getValue()
            if (seed < 0) {
                throw ConfigTypeException(key, "a UInt64")
            }
            UInt64(seed)
        case stringValue: JsonString =>
            match (UInt64.tryParse(stringValue.getValue())) {
                case Some(seed) => seed
                case None => throw ConfigTypeException(key, "a UInt64")
            }
        case _ => throw ConfigTypeException(key, "a UInt64")
    }
}

public func loadRestestConfig(path!: String = getRestestConfigPath()): RestestConfig {
    let decoder = Decoder()
    decoder.load(path)
    let root = decoder.decode()
    RestestConfig(
        requireString(requireValue(root.get("project"), "project"), "project"),
        requireUInt64(requireValue(root.get("seed"), "seed"), "seed")
    )
}
