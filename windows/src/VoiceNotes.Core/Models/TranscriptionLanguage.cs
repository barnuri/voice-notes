namespace VoiceNotes.Core.Models;

public sealed class TranscriptionLanguage
{
    public static readonly TranscriptionLanguage HebrewWithEnglish = new(
        id: "hebrewWithEnglish",
        title: "Hebrew + English words",
        code: "he",
        prompt: "שלום, היום עשינו deploy לשרת ושלחנו email לצוות לפני ה-meeting.");

    public static readonly TranscriptionLanguage English = new(id: "english", title: "English", code: "en", prompt: null);

    public static readonly TranscriptionLanguage Auto = new(id: "auto", title: "Auto-detect", code: "auto", prompt: null);

    public static IReadOnlyList<TranscriptionLanguage> All { get; } = [HebrewWithEnglish, English, Auto];

    private TranscriptionLanguage(string id, string title, string code, string? prompt)
    {
        Id = id;
        Title = title;
        Code = code;
        Prompt = prompt;
    }

    public string Id { get; }

    public string Title { get; }

    public string Code { get; }

    public string? Prompt { get; }

    public static TranscriptionLanguage FromId(string? id) =>
        All.FirstOrDefault(language => language.Id == id) ?? HebrewWithEnglish;

    public override string ToString() => Title;
}
