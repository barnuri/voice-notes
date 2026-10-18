using System.Globalization;

namespace VoiceNotes.Windows.Services;

internal sealed class FileLog(string path)
{
    private const long MaxBytes = 5 * 1024 * 1024;
    private const string RotatedSuffix = ".1";
    private readonly Lock gate = new();

    internal string Directory => Path.GetDirectoryName(path) ?? ".";

    internal void Info(string message) => Write("INFO", message);

    internal void Error(string message, Exception? error = null) =>
        Write("ERROR", error is null ? message : $"{message} {error}");

    private void Write(string level, string message)
    {
        var line = string.Create(CultureInfo.InvariantCulture, $"{DateTimeOffset.UtcNow:O} {level} {message}{Environment.NewLine}");
        lock (gate)
        {
            try
            {
                System.IO.Directory.CreateDirectory(Directory);
                RotateIfFull();
                File.AppendAllText(path, line);
            }
            catch (IOException)
            {
            }
            catch (UnauthorizedAccessException)
            {
            }
        }
    }

    private void RotateIfFull()
    {
        var file = new FileInfo(path);
        if (!file.Exists || file.Length < MaxBytes)
        {
            return;
        }
        File.Move(path, path + RotatedSuffix, overwrite: true);
    }
}
