using VoiceNotes.Core.Models;

namespace VoiceNotes.Core.Services;

public sealed class DictationController : IDisposable
{
    public static readonly TimeSpan DefaultMeterInterval = TimeSpan.FromMilliseconds(50);
    private const string ChunkSeparator = " ";

    private readonly IAudioRecorder recorder;
    private readonly ITranscriber transcriber;
    private readonly Func<TranscriptionEndpoint?> endpoint;
    private readonly ITextTyper typer;
    private readonly TimeProvider clock;
    private readonly TimeSpan meterInterval;
    private readonly SpeechChunker chunker;
    private CancellationTokenSource? metering;
    private Task queueTail = Task.CompletedTask;
    private bool hasTypedThisSession;
    private DictationPhase phase = DictationPhase.Idle;

    public DictationController(
        IAudioRecorder recorder,
        ITranscriber transcriber,
        Func<TranscriptionEndpoint?> endpoint,
        ITextTyper typer,
        TimeProvider? clock = null,
        TimeSpan? meterInterval = null)
    {
        this.recorder = recorder;
        this.transcriber = transcriber;
        this.endpoint = endpoint;
        this.typer = typer;
        this.clock = clock ?? TimeProvider.System;
        this.meterInterval = meterInterval ?? DefaultMeterInterval;
        chunker = new SpeechChunker(this.clock.GetUtcNow());
    }

    public event Action<DictationPhase>? PhaseChanged;

    public event Action<Exception>? ErrorOccurred;

    public DictationPhase Phase
    {
        get => phase;
        private set
        {
            if (phase == value)
            {
                return;
            }
            phase = value;
            PhaseChanged?.Invoke(value);
        }
    }

    public float Level { get; private set; }

    public string? ErrorMessage { get; private set; }

    public Task ToggleAsync()
    {
        switch (Phase)
        {
            case DictationPhase.Idle:
                StartListening();
                return Task.CompletedTask;
            case DictationPhase.Listening:
            case DictationPhase.Paused:
                return StopAsync();
            default:
                return Task.CompletedTask;
        }
    }

    public void Pause()
    {
        if (Phase != DictationPhase.Listening)
        {
            return;
        }
        Phase = DictationPhase.Paused;
        CloseChunk();
    }

    public void Resume()
    {
        if (Phase != DictationPhase.Paused)
        {
            return;
        }
        StartRecording();
    }

    public async Task StopAsync()
    {
        if (Phase is not (DictationPhase.Listening or DictationPhase.Paused))
        {
            return;
        }
        var wasListening = Phase == DictationPhase.Listening;
        Phase = DictationPhase.Transcribing;
        if (wasListening)
        {
            CloseChunk();
        }
        await queueTail;
        Phase = DictationPhase.Idle;
    }

    public void Dispose()
    {
        StopMetering();
        if (Phase != DictationPhase.Listening)
        {
            return;
        }
        if (recorder.Stop() is { } path)
        {
            DeleteQuietly(path);
        }
    }

    internal void Tick()
    {
        Level = recorder.Level;
        if (Phase != DictationPhase.Listening || !chunker.Observe(Level, clock.GetUtcNow()))
        {
            return;
        }
        RotateChunk();
    }

    private void StartListening()
    {
        ErrorMessage = null;
        if (endpoint() is null)
        {
            ReportError(TranscriptionException.NotConfigured());
            return;
        }
        hasTypedThisSession = false;
        StartRecording();
    }

    private void StartRecording()
    {
        try
        {
            recorder.Start();
        }
        catch (Exception error)
        {
            ReportError(error);
            return;
        }
        chunker.Reset(clock.GetUtcNow());
        Phase = DictationPhase.Listening;
        StartMetering();
    }

    private void CloseChunk()
    {
        StopMetering();
        Level = 0;
        var hasSpeech = chunker.HasSpeech;
        string? path;
        try
        {
            path = recorder.Stop();
        }
        catch (Exception error)
        {
            ReportError(error);
            return;
        }
        if (path is null)
        {
            ReportError(DictationException.RecordingNotSaved());
            return;
        }
        Enqueue(path, hasSpeech);
    }

    private void RotateChunk()
    {
        var hasSpeech = chunker.HasSpeech;
        chunker.Reset(clock.GetUtcNow());
        try
        {
            Enqueue(recorder.Rotate(), hasSpeech);
        }
        catch (Exception error)
        {
            ReportError(error);
        }
    }

    private void Enqueue(string path, bool hasSpeech)
    {
        var previous = queueTail;
        queueTail = TranscribeAfterAsync(previous, path, hasSpeech);
    }

    private async Task TranscribeAfterAsync(Task previous, string path, bool hasSpeech)
    {
        await previous;
        await TranscribeAndTypeAsync(path, hasSpeech);
    }

    private async Task TranscribeAndTypeAsync(string path, bool hasSpeech)
    {
        try
        {
            if (!hasSpeech || endpoint() is not { } target)
            {
                return;
            }
            var text = CollapseWhitespace(await transcriber.TranscribeAsync(path, target));
            if (text.Length == 0)
            {
                return;
            }
            typer.Type(hasTypedThisSession ? ChunkSeparator + text : text);
            hasTypedThisSession = true;
        }
        catch (Exception error)
        {
            ReportError(error);
        }
        finally
        {
            DeleteQuietly(path);
        }
    }

    private void StartMetering()
    {
        StopMetering();
        metering = new CancellationTokenSource();
        _ = MeterAsync(metering.Token);
    }

    private void StopMetering()
    {
        metering?.Cancel();
        metering?.Dispose();
        metering = null;
    }

    private async Task MeterAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(meterInterval, clock);
        try
        {
            while (await timer.WaitForNextTickAsync(cancellationToken))
            {
                Tick();
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private void ReportError(Exception error)
    {
        ErrorMessage = error.Message;
        ErrorOccurred?.Invoke(error);
    }

    private static string CollapseWhitespace(string text) =>
        string.Join(ChunkSeparator, text.Split(default(char[]), StringSplitOptions.RemoveEmptyEntries));

    private static void DeleteQuietly(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
