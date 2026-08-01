import Foundation

func logDebug(_ message: String) {
    print("DEBUG: \(message)")
    fflush(stdout)
}
