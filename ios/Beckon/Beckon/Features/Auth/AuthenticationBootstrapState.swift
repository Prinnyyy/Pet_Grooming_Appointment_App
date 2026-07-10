enum AuthenticationBootstrapState: Equatable {
    case ready
    case configurationError(message: String)
}
