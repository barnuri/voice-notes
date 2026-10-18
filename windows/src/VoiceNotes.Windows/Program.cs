using VoiceNotes.Windows.App;
using VoiceNotes.Windows.Services;

namespace VoiceNotes.Windows;

internal static class Program
{
    private const string SingleInstanceMutexName = @"Local\VoiceNotes.Windows.SingleInstance";

    [STAThread]
    private static void Main()
    {
        using var singleInstance = new Mutex(initiallyOwned: true, SingleInstanceMutexName, out var isFirstInstance);
        if (!isFirstInstance)
        {
            MessageBox.Show(
                "VoiceNotes is already running. Find its icon in the notification area.",
                "VoiceNotes",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            return;
        }
        var log = new FileLog(AppPaths.LogFile);
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (_, args) => log.Error("VoiceNotes hit an unexpected error.", args.Exception);
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
            log.Error("VoiceNotes stopped after an unexpected error.", args.ExceptionObject as Exception);
        ApplicationConfiguration.Initialize();
        using var application = new TrayApplication(log);
        Application.Run(application);
    }
}
