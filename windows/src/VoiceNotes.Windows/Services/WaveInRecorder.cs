using System.Runtime.InteropServices;
using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;
using VoiceNotes.Windows.Native;

namespace VoiceNotes.Windows.Services;

internal sealed unsafe class WaveInRecorder : IAudioRecorder, IDisposable
{
    private const int BufferCount = 8;
    private const int BufferMilliseconds = 50;
    private const int BufferBytes = WavWriter.ByteRate * BufferMilliseconds / 1000;
    private const ushort PcmFormatTag = 1;
    private const string ChunkFilePrefix = "dictation-";
    private const string ChunkFilePattern = "dictation-*.wav";
    private static readonly TimeSpan CaptureStopTimeout = TimeSpan.FromSeconds(2);

    private readonly string directory;
    private readonly FileLog log;
    private readonly Lock gate = new();
    private nint device;
    private WaveHeader* headers;
    private byte* audioMemory;
    private int queuedBuffers;
    private bool stopping;
    private AutoResetEvent? bufferDone;
    private Thread? captureThread;
    private WavWriter? writer;
    private volatile float level;

    internal WaveInRecorder(string directory, FileLog log)
    {
        this.directory = directory;
        this.log = log;
        DeleteLeftoverChunks();
    }

    public float Level => level;

    private bool IsRecording => device != 0;

    public void Start()
    {
        if (IsRecording)
        {
            throw new InvalidOperationException("The microphone is already recording.");
        }
        Directory.CreateDirectory(directory);
        writer = new WavWriter(NewChunkPath());
        try
        {
            OpenDevice();
        }
        catch
        {
            ReleaseDevice();
            DiscardWriter();
            throw;
        }
    }

    public string Rotate()
    {
        lock (gate)
        {
            var finished = writer ?? throw new InvalidOperationException("The microphone is not recording.");
            writer = new WavWriter(NewChunkPath());
            finished.Dispose();
            return finished.Path;
        }
    }

    public string? Stop()
    {
        if (!IsRecording)
        {
            return null;
        }
        lock (gate)
        {
            stopping = true;
            LogIfFailed(WinMM.WaveInReset(device), "stop the microphone");
        }
        bufferDone?.Set();
        if (captureThread is { } thread && !thread.Join(CaptureStopTimeout))
        {
            log.Error("The microphone capture thread did not stop in time.");
        }
        ReleaseDevice();
        level = 0;
        lock (gate)
        {
            var finished = writer;
            writer = null;
            finished?.Dispose();
            return finished?.Path;
        }
    }

    public void Dispose()
    {
        if (Stop() is { } path)
        {
            File.Delete(path);
        }
    }

    private void OpenDevice()
    {
        bufferDone = new AutoResetEvent(false);
        var format = new WaveFormat
        {
            FormatTag = PcmFormatTag,
            Channels = (ushort)WavWriter.Channels,
            SamplesPerSecond = WavWriter.SampleRate,
            AverageBytesPerSecond = WavWriter.ByteRate,
            BlockAlign = (ushort)WavWriter.BlockAlign,
            BitsPerSample = (ushort)WavWriter.BitsPerSample,
        };
        var eventHandle = bufferDone.SafeWaitHandle.DangerousGetHandle();
        Check(WinMM.WaveInOpen(out device, WinMM.WaveMapper, &format, eventHandle, 0, WinMM.CallbackEvent));

        headers = (WaveHeader*)NativeMemory.AllocZeroed((nuint)(BufferCount * sizeof(WaveHeader)));
        audioMemory = (byte*)NativeMemory.Alloc((nuint)(BufferCount * BufferBytes));
        stopping = false;
        queuedBuffers = 0;
        for (var index = 0; index < BufferCount; index++)
        {
            var header = &headers[index];
            header->Data = (nint)(audioMemory + (index * BufferBytes));
            header->BufferLength = BufferBytes;
            Check(WinMM.WaveInPrepareHeader(device, header, (uint)sizeof(WaveHeader)));
            Check(WinMM.WaveInAddBuffer(device, header, (uint)sizeof(WaveHeader)));
            queuedBuffers++;
        }
        Check(WinMM.WaveInStart(device));
        captureThread = new Thread(CaptureLoop) { IsBackground = true, Name = "VoiceNotes microphone" };
        captureThread.Start();
    }

    private void CaptureLoop()
    {
        var next = 0;
        while (true)
        {
            bufferDone!.WaitOne();
            while (IsDone(&headers[next]))
            {
                ConsumeAndRequeue(&headers[next]);
                next = (next + 1) % BufferCount;
            }
            lock (gate)
            {
                if (stopping && queuedBuffers == 0)
                {
                    return;
                }
            }
        }
    }

    private void ConsumeAndRequeue(WaveHeader* header)
    {
        var recorded = new ReadOnlySpan<byte>((void*)header->Data, (int)header->BytesRecorded);
        lock (gate)
        {
            header->Flags &= ~WinMM.HeaderDone;
            queuedBuffers--;
            if (recorded.Length > 0)
            {
                WriteRecorded(recorded);
                level = AudioLevel.FromPcm16(recorded);
            }
            if (stopping)
            {
                return;
            }
            var result = WinMM.WaveInAddBuffer(device, header, (uint)sizeof(WaveHeader));
            if (result == WinMM.NoError)
            {
                queuedBuffers++;
                return;
            }
            log.Error($"Windows can't queue a microphone buffer (error {result}).");
        }
    }

    private void WriteRecorded(ReadOnlySpan<byte> recorded)
    {
        try
        {
            writer?.Write(recorded);
        }
        catch (IOException error)
        {
            log.Error("VoiceNotes can't write the dictation recording.", error);
        }
    }

    private static bool IsDone(WaveHeader* header) => (Volatile.Read(ref header->Flags) & WinMM.HeaderDone) != 0;

    private void ReleaseDevice()
    {
        if (device != 0)
        {
            LogIfFailed(WinMM.WaveInReset(device), "stop the microphone");
            for (var index = 0; headers != null && index < BufferCount; index++)
            {
                LogIfFailed(WinMM.WaveInUnprepareHeader(device, &headers[index], (uint)sizeof(WaveHeader)), "release a microphone buffer");
            }
            LogIfFailed(WinMM.WaveInClose(device), "close the microphone");
            device = 0;
        }
        NativeMemory.Free(headers);
        NativeMemory.Free(audioMemory);
        headers = null;
        audioMemory = null;
        bufferDone?.Dispose();
        bufferDone = null;
        captureThread = null;
    }

    private void DiscardWriter()
    {
        var discarded = writer;
        writer = null;
        if (discarded is null)
        {
            return;
        }
        discarded.Dispose();
        File.Delete(discarded.Path);
    }

    private string NewChunkPath() => Path.Combine(directory, $"{ChunkFilePrefix}{Guid.NewGuid():N}.wav");

    private void DeleteLeftoverChunks()
    {
        if (!Directory.Exists(directory))
        {
            return;
        }
        foreach (var leftover in Directory.EnumerateFiles(directory, ChunkFilePattern))
        {
            try
            {
                File.Delete(leftover);
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException)
            {
                log.Error($"VoiceNotes can't delete the old recording {leftover}.", error);
            }
        }
    }

    private void LogIfFailed(int result, string action)
    {
        if (result != WinMM.NoError)
        {
            log.Error($"Windows can't {action} (error {result}).");
        }
    }

    private static void Check(int result)
    {
        if (result != WinMM.NoError)
        {
            throw new DictationException(
                $"VoiceNotes can't open the microphone (Windows error {result}). Connect a microphone. "
                + "Then check Settings > Privacy & security > Microphone > Let desktop apps access your microphone.");
        }
    }
}
