/// Supabase connection details for syncing scans to the backend.
///
/// The credentials are embedded directly in this file — no --dart-define
/// flags needed at build/run time. This is safe: the anon key is a PUBLIC
/// key (the same one the admin dashboard exposes); the RLS policies in
/// supabase/schema.sql are what actually restrict what it's allowed to do
/// (insert-only for scans).
///
/// ⚠️ Before building, replace the two placeholders below with your real
/// values from Supabase → Settings → API:
///   - [url]:     your project URL, e.g. https://abcdefgh.supabase.co
///   - [anonKey]: the "anon public" key — a long `eyJhbGci...` JWT string
///
/// Until you do, [isConfigured] stays false and scan syncing is a no-op.
class SupabaseConfig {
  // TODO: paste your Supabase project URL and anon public key here.
  static const String url = 'https://umvdhcmxmhpgdxseyfaa.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtdmRoY214bWhwZ2R4c2V5ZmFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyNzc5MzUsImV4cCI6MjEwMDg1MzkzNX0.EgHJLF3Zhe7rFQQLpQ-Kbwo6aENqlzCTdInB9XTa9b4';

  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.contains('YOUR-PROJECT-REF') &&
      !anonKey.contains('YOUR-SUPABASE-ANON-KEY');
}
