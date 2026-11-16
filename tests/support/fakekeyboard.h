#pragma once

#include <QRectF>
#include <qpa/qplatforminputcontext.h>

// The on-screen keyboard, as the device's Qt platform shows it: up when a text field asks
// for it, over the bottom of the window, until asked to go. It takes the place of the
// offscreen platform's input context, which has no keyboard, through Qt's own hook for tests
// (QInputMethodPrivate::testContext), so Qt.inputMethod reports it. As keyboard in QML, it
// says whether it's up and where.
class FakeKeyboard : public QPlatformInputContext
{
    Q_OBJECT
    Q_PROPERTY(bool visible READ isInputPanelVisible NOTIFY changed)
    // In window coordinates
    Q_PROPERTY(QRectF rect READ keyboardRect NOTIFY changed)

public:
    // Over the bottom height pixels of a window this size
    FakeKeyboard(QSizeF window, qreal height, QObject *parent = nullptr);
    ~FakeKeyboard() override;

    // Down, for a newly started app
    void reset();

    bool isValid() const override { return true; }
    void showInputPanel() override;
    void hideInputPanel() override;
    bool isInputPanelVisible() const override { return m_visible; }
    QRectF keyboardRect() const override;

signals:
    void changed();

private:
    void setVisible(bool visible);

    QRectF m_rect;
    bool m_visible = false;
};
