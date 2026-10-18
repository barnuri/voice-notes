using System.ComponentModel;
using System.Diagnostics;
using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;
using VoiceNotes.Windows.Services;
using VoiceNotes.Windows.Views;

namespace VoiceNotes.Windows.App;

internal sealed class TrayApplication : ApplicationContext
{
    private const string AppName = "VoiceNotes";
    private const int BalloonMilliseconds = 5000;

    private readonly FileLog log;
    private readonly SettingsStore settingsStore;
    private readonly HttpClient httpClient = new() { Timeout = Timeout.InfiniteTimeSpan };
    private readonly WaveInRecorder recorder;
    private readonly DictationController controller;
    private readonly GlobalHotKey hotKey = new();
    private readonly TrayIcons icons = new();
    private readonly NotifyIcon tray;
    private readonly ToolStripMenuItem toggleItem;
    private readonly DictationPill pill;
    private AppSettings settings;
    private string apiKey;
    private SettingsForm? settingsForm;

    internal TrayApplication(FileLog log)
    {
        this.log = log;
        settingsStore = new SettingsStore(AppPaths.SettingsFile, log);
        var isFirstRun = !settingsStore.Exists;
        settings = settingsStore.Load();
        apiKey = UnprotectApiKey(settings.ProtectedApiKey);

        recorder = new WaveInRecorder(AppPaths.RecordingDirectory, log);
        controller = new DictationController(recorder, new TranscriptionClient(httpClient), CurrentEndpoint, new SendInputTextTyper());
        controller.PhaseChanged += OnPhaseChanged;
        controller.ErrorOccurred += OnError;

        pill = new DictationPill(() => controller.Level);
        pill.PauseResumeRequested += (_, _) => PauseOrResume();
        pill.StopRequested += async (_, _) => await controller.StopAsync();

        toggleItem = new ToolStripMenuItem("", null, async (_, _) => await controller.ToggleAsync());
        var menu = new ContextMenuStrip();
        menu.Items.AddRange(
        [
            toggleItem,
            new ToolStripMenuItem("Settings…", null, (_, _) => OpenSettings()),
            new ToolStripMenuItem("Open log folder", null, (_, _) => OpenLogFolder()),
            new ToolStripSeparator(),
            new ToolStripMenuItem("Quit", null, (_, _) => Quit()),
        ]);
        tray = new NotifyIcon { ContextMenuStrip = menu, Visible = true };
        tray.DoubleClick += (_, _) => OpenSettings();
        UpdateTray(DictationPhase.Idle);

        hotKey.Pressed += async (_, _) => await controller.ToggleAsync();
        RegisterHotKey();
        log.Info("VoiceNotes started.");
        if (isFirstRun)
        {
            ShowBalloon($"VoiceNotes runs in the notification area. Press {settings.HotKey.DisplayString} to start dictation.", ToolTipIcon.Info);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            controller.Dispose();
            recorder.Dispose();
            hotKey.Dispose();
            tray.Dispose();
            icons.Dispose();
            pill.Dispose();
            settingsForm?.Dispose();
            httpClient.Dispose();
        }
        base.Dispose(disposing);
    }

    private TranscriptionEndpoint? CurrentEndpoint() =>
        TranscriptionEndpoint.Create(settings.BaseUrl, settings.Model, apiKey, settings.Language);

    private void PauseOrResume()
    {
        if (controller.Phase == DictationPhase.Paused)
        {
            controller.Resume();
            return;
        }
        controller.Pause();
    }

    private void OnPhaseChanged(DictationPhase phase)
    {
        DictationSounds.Play(phase);
        pill.ShowPhase(phase, settings.HotKey);
        UpdateTray(phase);
    }

    private void OnError(Exception error)
    {
        log.Error("Dictation failed.", error);
        DictationSounds.PlayError();
        ShowBalloon(error.Message, ToolTipIcon.Warning);
    }

    private void UpdateTray(DictationPhase phase)
    {
        tray.Icon = icons.For(phase);
        tray.Text = phase switch
        {
            DictationPhase.Listening => "VoiceNotes: listening",
            DictationPhase.Paused => "VoiceNotes: paused",
            DictationPhase.Transcribing => "VoiceNotes: finishing",
            _ => AppName,
        };
        toggleItem.Text = phase == DictationPhase.Idle
            ? $"Start dictation ({settings.HotKey.DisplayString})"
            : $"Stop dictation ({settings.HotKey.DisplayString})";
        toggleItem.Enabled = phase != DictationPhase.Transcribing;
    }

    private void RegisterHotKey()
    {
        if (hotKey.Register(settings.HotKey))
        {
            log.Info($"Dictation shortcut {settings.HotKey.DisplayString} is active.");
            return;
        }
        var message = $"VoiceNotes can't use the shortcut {settings.HotKey.DisplayString}. Another app may use it. "
            + "Open Settings from the VoiceNotes icon in the notification area, and choose a different shortcut.";
        log.Error(message);
        MessageBox.Show(message, AppName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
    }

    private void OpenSettings()
    {
        if (settingsForm is not null)
        {
            settingsForm.Activate();
            return;
        }
        hotKey.Unregister();
        settingsForm = new SettingsForm(settings, apiKey, StartupRegistration.IsEnabled);
        settingsForm.FormClosed += (_, _) => OnSettingsClosed();
        settingsForm.Show();
        settingsForm.Activate();
    }

    private void OnSettingsClosed()
    {
        var form = settingsForm;
        settingsForm = null;
        if (form?.Result is { } result)
        {
            ApplySettings(result, form.ApiKey, form.StartWithWindows);
        }
        form?.Dispose();
        RegisterHotKey();
        UpdateTray(controller.Phase);
    }

    private void ApplySettings(AppSettings result, string newApiKey, bool startWithWindows)
    {
        try
        {
            var updated = result with { ProtectedApiKey = ApiKeyProtector.Protect(newApiKey) };
            settingsStore.Save(updated);
            settings = updated;
            apiKey = newApiKey;
            log.Info("VoiceNotes saved the settings.");
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or Win32Exception)
        {
            log.Error("VoiceNotes can't save the settings.", error);
            MessageBox.Show($"VoiceNotes can't save the settings. {error.Message}", AppName, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        try
        {
            StartupRegistration.SetEnabled(startWithWindows);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or System.Security.SecurityException)
        {
            log.Error("VoiceNotes can't change the Start with Windows setting.", error);
            MessageBox.Show($"VoiceNotes can't change the Start with Windows setting. {error.Message}", AppName, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private string UnprotectApiKey(string protectedApiKey)
    {
        try
        {
            return ApiKeyProtector.Unprotect(protectedApiKey);
        }
        catch (Exception error) when (error is FormatException or Win32Exception)
        {
            log.Error("VoiceNotes can't decrypt the saved API key. Enter the key again in Settings.", error);
            return "";
        }
    }

    private void OpenLogFolder()
    {
        try
        {
            Directory.CreateDirectory(log.Directory);
            using var explorer = Process.Start(new ProcessStartInfo { FileName = log.Directory, UseShellExecute = true });
        }
        catch (Exception error) when (error is IOException or Win32Exception)
        {
            log.Error("VoiceNotes can't open the log folder.", error);
            ShowBalloon($"VoiceNotes can't open the log folder {log.Directory}.", ToolTipIcon.Warning);
        }
    }

    private void ShowBalloon(string message, ToolTipIcon icon) =>
        tray.ShowBalloonTip(BalloonMilliseconds, AppName, message, icon);

    private void Quit()
    {
        log.Info("VoiceNotes quit.");
        tray.Visible = false;
        ExitThread();
    }
}
