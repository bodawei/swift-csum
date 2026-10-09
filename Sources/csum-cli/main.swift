import ArgumentParser
import ChecksumCore
import Foundation

extension ChecksumAlgorithm: ExpressibleByArgument {}

struct CsumCLI: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "csum-cli",
            abstract: "Compute the checksum of a file."
        )
    }

    @Argument(help: "Full path to the file.")
    var path: String

    @Option(name: .shortAndLong, help: "The checksum algorithm to use.")
    var algorithm: ChecksumAlgorithm = .sha256

    func run() throws {
        let digest = try ChecksumCalculator.checksum(
            of: URL(fileURLWithPath: path),
            algorithm: algorithm
        )
        print(digest)
    }
}

CsumCLI.main()
