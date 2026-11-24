#pragma once

#include <QObject>
#include <QTimer>

// E-ink update modes for QML, via the pocketbook2 platform plugin.
//
// A2 is the fastest update (about 8 a second) but black and white only, so the screen looks
// dithered while it's on. Use it for one region while it scrolls, as the official apps do,
// then let the region redraw at full quality.
//
// Dynamic updates are faster than the default partial ones, for typing. The SDK's qml_test
// README calls this setQuickKeyboardEnterUpdateMode(), deprecated here in favour of
// setDynamicUpdateMode().
class Eink : public QObject
{
    Q_OBJECT
    // Whether system night mode is on, for images and colours that should keep their real
    // colours (night.js)
    Q_PROPERTY(bool nightMode READ nightMode NOTIFY nightModeChanged)

public:
    explicit Eink(QObject *parent = nullptr);

    // Lets system night mode invert the app as it does the built-in ones, and redraws on
    // toggle. InkView only inverts apps that opt in, which by default is only those in
    // /ebrmain. Call after the platform plugin has started.
    void followNightMode();
    bool nightMode() const { return m_nightMode; }

    // Trims the on-screen keyboard's own screen updates. Redrawing the area it covered is
    // left to the app, which redraws the whole window when the keyboard closes anyway; the
    // plugin's update of that area adds a full e-ink update (about 0.4 s) that everything
    // after it waits for. Word suggestions are hidden: inkview redraws them after each key
    // and waits for the panel to finish each one. Call after the platform plugin has started.
    void reduceKeyboardUpdates();

    // Switches a screen rectangle (window coordinates) to A2 for a flick. Stays in A2 until
    // leaveA2Soon() or leaveA2(). Calling again cancels a pending timed exit.
    Q_INVOKABLE void enterA2ForFlick(int x, int y, int width, int height);
    // Ends A2 and redraws the region normally once the last frames have shown. Call when
    // movement, including momentum, stops.
    Q_INVOKABLE void leaveA2Soon();
    // Ends A2 and redraws the region normally right away, e.g. when the region disappears
    Q_INVOKABLE void leaveA2();

    // Draws the next update in one high-quality pass. Otherwise a colour image in the
    // changed area (a cover) gets a second pass of its own, which flashes and briefly draws
    // it over anything on top of it, such as a menu.
    Q_INVOKABLE void requireHqUpdate();

    // Draws the next update with the fast black-and-white waveform, about half the time of
    // the standard one, for a button's pressed look: what the tap opens overlaps it, so it
    // waits until the pressed look has finished drawing.
    Q_INVOKABLE void requireFastUpdate();

    // Enables dynamic updates while a text field has focus. Disabling redraws the window at
    // normal quality.
    Q_INVOKABLE void setDynamicUpdates(bool enabled);

signals:
    void nightModeChanged();

private:
    // For leaveA2Soon(). Not the platform's timedLeaveA2(): the plugin cancels that when a
    // finger moves (its flickStarted), which most taps do, so tapping a button while the
    // list settled left A2 on.
    QTimer m_leaveA2Timer;
    bool m_dynamicUpdates = false;
    bool m_nightMode = false;
};
