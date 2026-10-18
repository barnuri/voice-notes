using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;
using VoiceNotes.Core.Tests.Fakes;

namespace VoiceNotes.Core.Tests.Services;

public sealed class DictationControllerTests
{
    private const float Silence = 0.01f;
    private static readonly DateTimeOffset Start = DateTimeOffset.FromUnixTimeSeconds(1_000);
    private static readonly TimeSpan NeverTicks = TimeSpan.FromHours(1);

    private readonly FakeRecorder recorder = new();
    private readonly FakeTyper typer = new();
    private readonly FakeClock clock = new(Start);
    private readonly TranscriptionEndpoint endpoint =
        TranscriptionEndpoint.Create("https://h/v1", "m", "", TranscriptionLanguage.HebrewWithEnglish)!;

    private DictationController Controller(FakeTranscriber transcriber, TranscriptionEndpoint? target = null, bool hasEndpoint = true)
    {
        var resolved = hasEndpoint ? target ?? endpoint : null;
        return new DictationController(recorder, transcriber, () => resolved, typer, clock, NeverTicks);
    }

    private DictationController Controller(params string[] replies) =>
        Controller(new FakeTranscriber([.. replies.Select(FakeTranscriber.Says)]));

    private static async Task SpeakThenStopAsync(DictationController controller)
    {
        await controller.ToggleAsync();
        controller.Tick();
        await controller.ToggleAsync();
    }

    private static async Task SpeakThenPauseAsync(DictationController controller)
    {
        await controller.ToggleAsync();
        controller.Tick();
        controller.Pause();
    }

    [Fact]
    public async Task ToggleTwiceTypesCollapsedTranscript()
    {
        using var controller = Controller("  שלום,   deploy\n done \n");
        await controller.ToggleAsync();
        Assert.Equal(DictationPhase.Listening, controller.Phase);
        controller.Tick();
        await controller.ToggleAsync();
        Assert.Equal(DictationPhase.Idle, controller.Phase);
        Assert.Equal(["שלום, deploy done"], typer.Typed);
        Assert.Null(controller.ErrorMessage);
    }

    [Fact]
    public async Task ReportsPhaseChangesInOrder()
    {
        var phases = new List<DictationPhase>();
        using var controller = Controller("hi");
        controller.PhaseChanged += phases.Add;
        await SpeakThenStopAsync(controller);
        Assert.Equal([DictationPhase.Listening, DictationPhase.Transcribing, DictationPhase.Idle], phases);
    }

    [Fact]
    public async Task EmptyTranscriptTypesNothing()
    {
        using var controller = Controller("   ");
        await SpeakThenStopAsync(controller);
        Assert.Empty(typer.Typed);
        Assert.Null(controller.ErrorMessage);
    }

    [Fact]
    public async Task RecorderFailureStaysIdleAndReportsError()
    {
        recorder.FailStart = true;
        var reported = new List<Exception>();
        using var controller = Controller();
        controller.ErrorOccurred += reported.Add;
        await controller.ToggleAsync();
        Assert.Equal(DictationPhase.Idle, controller.Phase);
        Assert.Equal("No microphone.", controller.ErrorMessage);
        Assert.Single(reported);
    }

    [Fact]
    public async Task TranscriptionErrorIsReportedAndNothingTyped()
    {
        var failure = TranscriptionException.Unreachable("h");
        using var controller = Controller(new FakeTranscriber(FakeTranscriber.Fails(failure)));
        await SpeakThenStopAsync(controller);
        Assert.Equal(DictationPhase.Idle, controller.Phase);
        Assert.Empty(typer.Typed);
        Assert.Equal(failure.Message, controller.ErrorMessage);
    }

    [Fact]
    public async Task TypingErrorIsReported()
    {
        typer.Failure = new DictationException("Typing blocked.");
        using var controller = Controller("hello");
        await SpeakThenStopAsync(controller);
        Assert.Equal("Typing blocked.", controller.ErrorMessage);
    }

    [Fact]
    public async Task RemovesRecordingAfterTyping()
    {
        using var controller = Controller("hello");
        await SpeakThenStopAsync(controller);
        var path = Assert.Single(recorder.Segments);
        Assert.False(File.Exists(path));
    }

    [Fact]
    public async Task TypesEachChunkWhileStillListening()
    {
        using var controller = Controller("first part.", "second part.");
        await controller.ToggleAsync();
        clock.Now = Start + SpeechChunker.DefaultMinChunk;
        controller.Tick();
        recorder.Level = Silence;
        clock.Now = Start + SpeechChunker.DefaultMinChunk + TimeSpan.FromSeconds(1);
        controller.Tick();
        Assert.Equal(DictationPhase.Listening, controller.Phase);
        Assert.Equal(["first part."], typer.Typed);

        recorder.Level = 0.8f;
        controller.Tick();
        await controller.ToggleAsync();
        Assert.Equal(["first part.", " second part."], typer.Typed);
    }

    [Fact]
    public async Task SilentChunkIsNotTranscribed()
    {
        recorder.Level = Silence;
        var transcriber = new FakeTranscriber(FakeTranscriber.Says("תודה רבה"));
        using var controller = Controller(transcriber);
        await SpeakThenStopAsync(controller);
        Assert.Equal(0, transcriber.CallCount);
        Assert.Empty(typer.Typed);
        Assert.False(File.Exists(Assert.Single(recorder.Segments)));
    }

    [Fact]
    public async Task MissingEndpointDoesNotStartListening()
    {
        using var controller = Controller(new FakeTranscriber(), hasEndpoint: false);
        await controller.ToggleAsync();
        Assert.Equal(DictationPhase.Idle, controller.Phase);
        Assert.Equal(TranscriptionException.NotConfigured().Message, controller.ErrorMessage);
        Assert.Empty(recorder.Segments);
    }

    [Fact]
    public async Task PauseTypesSpokenChunkThenResumeContinues()
    {
        using var controller = Controller("before pause.", "after pause.");
        await SpeakThenPauseAsync(controller);
        Assert.Equal(DictationPhase.Paused, controller.Phase);
        Assert.Equal(0, controller.Level);
        controller.Resume();
        Assert.Equal(DictationPhase.Listening, controller.Phase);
        controller.Tick();
        await controller.StopAsync();
        Assert.Equal(DictationPhase.Idle, controller.Phase);
        Assert.Equal(["before pause.", " after pause."], typer.Typed);
        Assert.Equal(2, recorder.Segments.Count);
    }

    [Fact]
    public async Task StopWhilePausedFinishesWithoutError()
    {
        using var controller = Controller("only part.");
        await SpeakThenPauseAsync(controller);
        await controller.ToggleAsync();
        Assert.Equal(DictationPhase.Idle, controller.Phase);
        Assert.Null(controller.ErrorMessage);
        Assert.Equal(["only part."], typer.Typed);
    }

    [Fact]
    public async Task TickPublishesLevel()
    {
        using var controller = Controller();
        await controller.ToggleAsync();
        recorder.Level = 0.4f;
        controller.Tick();
        Assert.Equal(0.4f, controller.Level);
        await controller.StopAsync();
    }

    [Fact]
    public async Task NewSessionStartsWithoutLeadingSpace()
    {
        using var controller = Controller("one.", "two.");
        await SpeakThenStopAsync(controller);
        await SpeakThenStopAsync(controller);
        Assert.Equal(["one.", "two."], typer.Typed);
    }

    [Fact]
    public async Task PauseAndResumeIgnoreWrongPhases()
    {
        using var controller = Controller();
        controller.Pause();
        controller.Resume();
        Assert.Equal(DictationPhase.Idle, controller.Phase);
        await controller.StopAsync();
        Assert.Equal(DictationPhase.Idle, controller.Phase);
        Assert.Empty(recorder.Segments);
    }
}
