namespace VoiceNotes.Windows.Services;

internal static class AppPaths
{
    private const string AppFolder = "VoiceNotes";

    internal static string SettingsFile { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), AppFolder, "windows-settings.json");

    internal static string LogDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppFolder, "logs");

    internal static string LogFile { get; } = Path.Combine(LogDirectory, "voicenotes.log");

    internal static string RecordingDirectory { get; } = Path.Combine(Path.GetTempPath(), "VoiceNotesDictation");
}
