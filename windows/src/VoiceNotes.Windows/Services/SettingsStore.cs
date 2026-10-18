using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;

namespace VoiceNotes.Windows.Services;

internal sealed class SettingsStore(string path, FileLog log)
{
    private const string TemporarySuffix = ".tmp";

    internal bool Exists => File.Exists(path);

    internal AppSettings Load()
    {
        if (!Exists)
        {
            return new AppSettings();
        }
        try
        {
            return AppSettingsSerializer.Deserialize(File.ReadAllText(path));
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            log.Error($"VoiceNotes can't read the settings file {path}. VoiceNotes uses the default settings.", error);
            return new AppSettings();
        }
    }

    internal void Save(AppSettings settings)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporaryPath = path + TemporarySuffix;
        File.WriteAllText(temporaryPath, AppSettingsSerializer.Serialize(settings));
        File.Move(temporaryPath, path, overwrite: true);
    }
}
