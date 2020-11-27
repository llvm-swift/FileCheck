import ArgumentParser
import FileCheck
import Foundation

private extension FileCheckOptions {
    init(_ command: FileCheckCommand) {
        var options = FileCheckOptions()
        if command.disableColors {
            options.insert(.disableColors)
        }

        if command.useStrictWhitespace {
            options.insert(.strictWhitespace)
        }

        if command.allowEmptyInput {
            options.insert(.allowEmptyInput)
        }

        if command.matchFullLines {
            options.insert(.matchFullLines)
        }

        self = options
    }
}

struct FileCheckCommand: ParsableCommand {
    static var configuration = CommandConfiguration(commandName: "filecheck")

    @Flag(help: "Disable colorized diagnostics.")
    var disableColors = false

    @Flag(help: "Do not treat all horizontal whitespace as equivalent.")
    var useStrictWhitespace = false

    @Flag(
        name: [.customShort("e"), .long],
        help: """
        Allow the input file to be empty. This is useful when \
        making checks that some error message does not occur, \
        for example.
        """
    )
    var allowEmptyInput = false

    @Flag(help: """
    Require all positive matches to cover an entire input line. \
    Allows leading and trailing whitespace if \
    --strict-whitespace is not also used.
    """)
    var matchFullLines = false

    @Option(
        help: """
        Specifies one or more prefixes to match. By default these \
        patterns are prefixed with “CHECK”.
        """
    )
    var prefixes: [String] = []

    @Option(
        name: .shortAndLong,
        help: "The file to use for checked input. Defaults to stdin."
    )
    var inputFile: String?

    @Argument
    var file: String

    mutating func run() throws {
        let fileHandle: FileHandle
        if let input = inputFile {
            guard let handle = FileHandle(forReadingAtPath: input) else {
                throw ValidationError("unable to open check file at path \(input).")
            }

            fileHandle = handle
        } else {
            fileHandle = .standardInput
        }

        let checkPrefixes = prefixes + ["CHECK"]
        let matchedAll = fileCheckOutput(of: .stdout,
                                         withPrefixes: checkPrefixes,
                                         checkNot: [],
                                         against: .filePath(file),
                                         options: FileCheckOptions(self)) {

            // FIXME: Better way to stream this data?
            FileHandle.standardOutput.write(fileHandle.readDataToEndOfFile())
        }


        if !matchedAll {
            throw ExitCode.failure
        }
    }
}

FileCheckCommand.main()
