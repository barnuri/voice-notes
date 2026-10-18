using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using VoiceNotes.Core.Models;

namespace VoiceNotes.Core.Services;

public sealed class TranscriptionClient : ITranscriber
{
    public static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(120);
    private const string ModelField = "model";
    private const string FormatField = "response_format";
    private const string JsonFormat = "json";
    private const string LanguageField = "language";
    private const string PromptField = "prompt";
    private const string FileField = "file";
    private const string AudioMimeType = "audio/wav";
    private const string BearerScheme = "Bearer";
    private const string TextProperty = "text";
    private const string ErrorProperty = "error";
    private const string MessageProperty = "message";
    private const int ErrorPreviewBytes = 300;

    private readonly HttpClient httpClient;

    public TranscriptionClient(HttpClient httpClient)
    {
        this.httpClient = httpClient;
    }

    public async Task<string> TranscribeAsync(string audioPath, TranscriptionEndpoint endpoint, CancellationToken cancellationToken = default)
    {
        using var request = await BuildRequestAsync(audioPath, endpoint, cancellationToken);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(RequestTimeout);
        HttpResponseMessage response;
        try
        {
            response = await httpClient.SendAsync(request, timeout.Token);
        }
        catch (HttpRequestException error)
        {
            throw TranscriptionException.Unreachable(endpoint.Url.Host, error);
        }
        catch (TaskCanceledException error) when (!cancellationToken.IsCancellationRequested)
        {
            throw TranscriptionException.TimedOut(endpoint.Url.Host, RequestTimeout, error);
        }
        using (response)
        {
            var body = await response.Content.ReadAsByteArrayAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                throw TranscriptionException.Server((int)response.StatusCode, ReadErrorMessage(body));
            }
            return DecodeText(body) ?? throw TranscriptionException.UnreadableResponse();
        }
    }

    internal static async Task<HttpRequestMessage> BuildRequestAsync(string audioPath, TranscriptionEndpoint endpoint, CancellationToken cancellationToken)
    {
        var body = new MultipartBody();
        body.AddField(ModelField, endpoint.Model);
        body.AddField(FormatField, JsonFormat);
        body.AddField(LanguageField, endpoint.Language.Code);
        if (endpoint.Language.Prompt is { } prompt)
        {
            body.AddField(PromptField, prompt);
        }
        var audio = await File.ReadAllBytesAsync(audioPath, cancellationToken);
        body.AddFile(FileField, Path.GetFileName(audioPath), AudioMimeType, audio);

        var content = new ByteArrayContent(body.ToArray());
        content.Headers.ContentType = MediaTypeHeaderValue.Parse(body.ContentType);
        var request = new HttpRequestMessage(HttpMethod.Post, endpoint.Url) { Content = content };
        if (endpoint.ApiKey.Length > 0)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue(BearerScheme, endpoint.ApiKey);
        }
        return request;
    }

    internal static string? DecodeText(byte[] body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object
                || !root.TryGetProperty(TextProperty, out var text)
                || text.ValueKind != JsonValueKind.String)
            {
                return null;
            }
            return text.GetString()?.Trim();
        }
        catch (JsonException)
        {
            return null;
        }
    }

    internal static string ReadErrorMessage(byte[] body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            var root = document.RootElement;
            if (root.ValueKind == JsonValueKind.Object && root.TryGetProperty(ErrorProperty, out var error))
            {
                if (error.ValueKind == JsonValueKind.String)
                {
                    return error.GetString() ?? "";
                }
                if (error.ValueKind == JsonValueKind.Object
                    && error.TryGetProperty(MessageProperty, out var message)
                    && message.ValueKind == JsonValueKind.String)
                {
                    return message.GetString() ?? "";
                }
            }
        }
        catch (JsonException)
        {
        }
        return Encoding.UTF8.GetString(body, 0, Math.Min(body.Length, ErrorPreviewBytes));
    }
}
