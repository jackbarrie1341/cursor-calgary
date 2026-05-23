import Foundation

enum AppConfig {
    static let backendBaseURL = URL(string: "http://localhost:3000")!
    static let supabaseURL = URL(string: "https://ggcfzetyfjodeqxcsytu.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdnY2Z6ZXR5ZmpvZGVxeGNzeXR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1NTQ5MzEsImV4cCI6MjA5NTEzMDkzMX0.1KmYtENwD5rajn59nk8VuXhcHgrlRpR7zxvwsb3jqmI"

    static var hasSupabaseConfig: Bool {
        supabaseURL.host != "YOUR_PROJECT_REF.supabase.co" && supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY"
    }
}

enum AppConfigurationError: LocalizedError {
    case missingSupabaseConfig

    var errorDescription: String? {
        switch self {
        case .missingSupabaseConfig:
            "Set your Supabase URL and anon key in AppConfig.swift before using the app."
        }
    }
}
