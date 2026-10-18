using System.Drawing.Drawing2D;
using VoiceNotes.Core.Models;
using VoiceNotes.Windows.Native;

namespace VoiceNotes.Windows.Views;

internal sealed class DictationPill : Form
{
    private const float BaseDpi = 96f;
    private const float PillWidth = 262;
    private const float PillHeight = 44;
    private const float PaddingLeft = 14;
    private const float PaddingRight = 8;
    private const float WaveformWidth = 72;
    private const float WaveformHeight = 22;
    private const float Gap = 12;
    private const float ButtonDiameter = 28;
    private const float ButtonGap = 8;
    private const float BarWidth = 3;
    private const float BarGap = 2;
    private const float MinBarHeight = 3;
    private const double LevelCurve = 0.6;
    private const float TopMargin = 12;
    private const int SampleIntervalMilliseconds = 70;
    private const float StatusFontSize = 10;
    private const int HistoryCapacity = (int)(WaveformWidth / (BarWidth + BarGap));

    private readonly Func<float> levelSource;
    private readonly System.Windows.Forms.Timer sampler = new() { Interval = SampleIntervalMilliseconds };
    private readonly ToolTip toolTip = new();
    private readonly Queue<float> history = new();
    private DictationPhase phase = DictationPhase.Idle;
    private string shortcut = HotKey.DefaultDictation.DisplayString;
    private Point? dragOffset;
    private string? toolTipText;

    internal DictationPill(Func<float> levelSource)
    {
        this.levelSource = levelSource;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        BackColor = Palette.PillBackground;
        AccessibleName = "Dictation";
        Text = "VoiceNotes dictation";
        Font = new Font(SystemFonts.MessageBoxFont?.FontFamily ?? FontFamily.GenericSansSerif, StatusFontSize, FontStyle.Bold);
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
        ApplyScale();
        sampler.Tick += (_, _) => Sample();
    }

    internal event EventHandler? PauseResumeRequested;

    internal event EventHandler? StopRequested;

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            var parameters = base.CreateParams;
            parameters.ExStyle |= User32.WsExNoActivate | User32.WsExToolWindow | User32.WsExTopMost;
            return parameters;
        }
    }

    private Color Tint => phase == DictationPhase.Paused ? Palette.Paused : Palette.Recording;

    private bool ShowsButtons => phase is DictationPhase.Listening or DictationPhase.Paused;

    private RectangleF PauseButton => new(
        Dpi(PillWidth - PaddingRight - ButtonDiameter - ButtonGap - ButtonDiameter),
        Dpi((PillHeight - ButtonDiameter) / 2),
        Dpi(ButtonDiameter),
        Dpi(ButtonDiameter));

    private RectangleF StopButton => new(
        Dpi(PillWidth - PaddingRight - ButtonDiameter),
        Dpi((PillHeight - ButtonDiameter) / 2),
        Dpi(ButtonDiameter),
        Dpi(ButtonDiameter));

    internal void ShowPhase(DictationPhase newPhase, HotKey hotKey)
    {
        shortcut = hotKey.DisplayString;
        var wasHidden = phase == DictationPhase.Idle || !Visible;
        phase = newPhase;
        if (newPhase == DictationPhase.Idle)
        {
            sampler.Stop();
            Hide();
            return;
        }
        if (wasHidden)
        {
            ResetHistory();
            MoveToTopCenterOfCursorScreen();
            Show();
        }
        sampler.Enabled = newPhase == DictationPhase.Listening;
        Invalidate();
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == User32.WmMouseActivate)
        {
            m.Result = User32.MouseActivateNoActivate;
            return;
        }
        base.WndProc(ref m);
    }

    protected override void OnDpiChanged(DpiChangedEventArgs e)
    {
        base.OnDpiChanged(e);
        ApplyScale();
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        using var shape = RoundedRectangles.Capsule(new RectangleF(0, 0, Width, Height));
        Region?.Dispose();
        Region = new Region(shape);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var graphics = e.Graphics;
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using (var border = new Pen(Color.FromArgb(115, Tint), 1))
        using (var outline = RoundedRectangles.Capsule(new RectangleF(0.5f, 0.5f, Width - 1, Height - 1)))
        {
            graphics.DrawPath(border, outline);
        }
        PaintWaveform(graphics);
        PaintStatus(graphics);
        if (!ShowsButtons)
        {
            return;
        }
        PaintPauseButton(graphics);
        PaintStopButton(graphics);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left)
        {
            return;
        }
        if (ShowsButtons && PauseButton.Contains(e.Location))
        {
            PauseResumeRequested?.Invoke(this, EventArgs.Empty);
            return;
        }
        if (ShowsButtons && StopButton.Contains(e.Location))
        {
            StopRequested?.Invoke(this, EventArgs.Empty);
            return;
        }
        dragOffset = e.Location;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        if (dragOffset is { } offset)
        {
            var cursor = Cursor.Position;
            Location = new Point(cursor.X - offset.X, cursor.Y - offset.Y);
            return;
        }
        UpdateToolTip(e.Location);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        dragOffset = null;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            sampler.Dispose();
            toolTip.Dispose();
        }
        base.Dispose(disposing);
    }

    private void PaintWaveform(Graphics graphics)
    {
        var color = phase == DictationPhase.Listening ? Tint : Color.Gray;
        using var brush = new SolidBrush(color);
        var height = Dpi(WaveformHeight);
        var top = (Height - height) / 2;
        var x = Dpi(PaddingLeft + WaveformWidth) - (history.Count * Dpi(BarWidth + BarGap));
        foreach (var level in history)
        {
            var barHeight = Math.Max(Dpi(MinBarHeight), (float)Math.Pow(Math.Clamp(level, 0, 1), LevelCurve) * height);
            var bar = new RectangleF(x, top + ((height - barHeight) / 2), Dpi(BarWidth), barHeight);
            using var path = RoundedRectangles.Capsule(bar);
            graphics.FillPath(brush, path);
            x += Dpi(BarWidth + BarGap);
        }
    }

    private void PaintStatus(Graphics graphics)
    {
        var title = phase switch
        {
            DictationPhase.Listening => "Listening",
            DictationPhase.Paused => "Paused",
            _ => "Finishing…",
        };
        var left = Dpi(PaddingLeft + WaveformWidth + Gap);
        var bounds = new Rectangle((int)left, 0, (int)(PauseButton.Left - left), Height);
        TextRenderer.DrawText(
            graphics,
            title,
            Font,
            bounds,
            Palette.PillText,
            TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis);
    }

    private void PaintPauseButton(Graphics graphics)
    {
        var button = PauseButton;
        using var fill = new SolidBrush(Tint);
        graphics.FillEllipse(fill, button);
        using var white = new SolidBrush(Color.White);
        var center = new PointF(button.Left + (button.Width / 2), button.Top + (button.Height / 2));
        if (phase == DictationPhase.Paused)
        {
            var dot = Dpi(10);
            graphics.FillEllipse(white, center.X - (dot / 2), center.Y - (dot / 2), dot, dot);
            return;
        }
        var barWidth = Dpi(3);
        var barHeight = Dpi(11);
        var spacing = Dpi(2);
        graphics.FillRectangle(white, center.X - spacing - barWidth, center.Y - (barHeight / 2), barWidth, barHeight);
        graphics.FillRectangle(white, center.X + spacing, center.Y - (barHeight / 2), barWidth, barHeight);
    }

    private void PaintStopButton(Graphics graphics)
    {
        var button = StopButton;
        using var fill = new SolidBrush(Palette.StopButton);
        graphics.FillEllipse(fill, button);
        using var white = new SolidBrush(Color.White);
        var side = Dpi(10);
        graphics.FillRectangle(
            white,
            button.Left + ((button.Width - side) / 2),
            button.Top + ((button.Height - side) / 2),
            side,
            side);
    }

    private void UpdateToolTip(Point location)
    {
        string? text = null;
        if (ShowsButtons && PauseButton.Contains(location))
        {
            text = phase == DictationPhase.Paused ? "Resume" : "Pause";
        }
        else if (ShowsButtons && StopButton.Contains(location))
        {
            text = $"Stop and type ({shortcut})";
        }
        if (text == toolTipText)
        {
            return;
        }
        toolTipText = text;
        toolTip.SetToolTip(this, text);
    }

    private void Sample()
    {
        if (history.Count >= HistoryCapacity)
        {
            history.Dequeue();
        }
        history.Enqueue(levelSource());
        Invalidate();
    }

    private void ResetHistory()
    {
        history.Clear();
        for (var index = 0; index < HistoryCapacity; index++)
        {
            history.Enqueue(0);
        }
    }

    private void MoveToTopCenterOfCursorScreen()
    {
        var area = Screen.FromPoint(Cursor.Position).WorkingArea;
        Location = new Point(area.Left + ((area.Width - Width) / 2), area.Top + (int)Dpi(TopMargin));
    }

    private void ApplyScale()
    {
        Size = new Size((int)Dpi(PillWidth), (int)Dpi(PillHeight));
    }

    private float Dpi(float value) => value * DeviceDpi / BaseDpi;
}
