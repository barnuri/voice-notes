using VoiceNotes.Core.Models;

namespace VoiceNotes.Windows.Views;

internal sealed class SettingsForm : Form
{
    private const int FieldWidth = 340;
    private const string InvalidUrlMessage =
        "Enter an https:// address. VoiceNotes accepts http:// only for this computer (127.0.0.1 or localhost).";
    private const string MissingModelMessage = "Enter a model name.";

    private readonly TextBox serverUrl = new() { Width = FieldWidth };
    private readonly TextBox model = new() { Width = FieldWidth };
    private readonly TextBox apiKey = new() { Width = FieldWidth, UseSystemPasswordChar = true };
    private readonly ComboBox language = new() { Width = FieldWidth, DropDownStyle = ComboBoxStyle.DropDownList };
    private readonly HotKeyBox shortcut = new() { Width = FieldWidth };
    private readonly CheckBox startWithWindows = new() { Text = "Start VoiceNotes when you sign in to Windows", AutoSize = true };
    private readonly Label validation = new() { AutoSize = true, ForeColor = Color.Firebrick, MaximumSize = new Size(FieldWidth, 0) };

    internal SettingsForm(AppSettings settings, string currentApiKey, bool startsWithWindows)
    {
        Text = "VoiceNotes Settings";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        AutoScaleMode = AutoScaleMode.Dpi;
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        Font = SystemFonts.MessageBoxFont ?? DefaultFont;
        Padding = new Padding(12);

        serverUrl.Text = settings.BaseUrl;
        model.Text = settings.Model;
        apiKey.Text = currentApiKey;
        language.Items.AddRange([.. TranscriptionLanguage.All]);
        language.SelectedItem = settings.Language;
        shortcut.HotKey = settings.HotKey;
        startWithWindows.Checked = startsWithWindows;

        var save = new Button { Text = "Save", DialogResult = DialogResult.None, AutoSize = true };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
        save.Click += (_, _) => SaveIfValid();
        cancel.Click += (_, _) => Close();
        AcceptButton = save;
        CancelButton = cancel;

        var buttons = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Dock = DockStyle.Fill };
        buttons.Controls.AddRange([cancel, save]);

        var layout = new TableLayoutPanel { ColumnCount = 2, AutoSize = true, Dock = DockStyle.Fill };
        AddRow(layout, "Server address", serverUrl);
        AddRow(layout, "Model", model);
        AddRow(layout, "API key", apiKey, "Optional. Windows encrypts the key for your user account.");
        AddRow(layout, "Language", language);
        AddRow(layout, "Dictation shortcut", shortcut, "Click the box, then press the new shortcut.");
        AddRow(layout, "", startWithWindows);
        AddRow(layout, "", validation);
        AddRow(layout, "", buttons);
        Controls.Add(layout);
    }

    internal AppSettings? Result { get; private set; }

    internal string ApiKey => apiKey.Text.Trim();

    internal bool StartWithWindows => startWithWindows.Checked;

    private static void AddRow(TableLayoutPanel layout, string title, Control field, string? hint = null)
    {
        var row = layout.RowCount++;
        layout.Controls.Add(new Label { Text = title, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(3, 8, 12, 3) }, 0, row);
        if (hint is null)
        {
            layout.Controls.Add(field, 1, row);
            return;
        }
        var stack = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false, Margin = Padding.Empty };
        stack.Controls.Add(field);
        stack.Controls.Add(new Label { Text = hint, AutoSize = true, ForeColor = SystemColors.GrayText, MaximumSize = new Size(FieldWidth, 0) });
        layout.Controls.Add(stack, 1, row);
    }

    private void SaveIfValid()
    {
        if (ServiceBaseUrl.Parse(serverUrl.Text) is null)
        {
            ShowValidation(InvalidUrlMessage, serverUrl);
            return;
        }
        if (string.IsNullOrWhiteSpace(model.Text))
        {
            ShowValidation(MissingModelMessage, model);
            return;
        }
        var selectedLanguage = language.SelectedItem as TranscriptionLanguage ?? TranscriptionLanguage.HebrewWithEnglish;
        Result = new AppSettings
        {
            BaseUrl = serverUrl.Text.Trim(),
            Model = model.Text.Trim(),
            LanguageId = selectedLanguage.Id,
            HotKey = shortcut.HotKey,
        };
        DialogResult = DialogResult.OK;
        Close();
    }

    private void ShowValidation(string message, Control field)
    {
        validation.Text = message;
        field.Focus();
    }
}
