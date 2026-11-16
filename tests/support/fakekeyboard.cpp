#include "fakekeyboard.h"

#include <QGuiApplication>
#include <private/qinputmethod_p.h>

FakeKeyboard::FakeKeyboard(QSizeF window, qreal height, QObject *parent)
    : m_rect(0, window.height() - height, window.width(), height)
{
    setParent(parent);
    QInputMethodPrivate::get(QGuiApplication::inputMethod())->testContext = this;
}

FakeKeyboard::~FakeKeyboard()
{
    QInputMethodPrivate::get(QGuiApplication::inputMethod())->testContext = nullptr;
}

void FakeKeyboard::reset()
{
    setVisible(false);
}

void FakeKeyboard::showInputPanel()
{
    setVisible(true);
}

void FakeKeyboard::hideInputPanel()
{
    setVisible(false);
}

// Nothing while it's down, as the platform reports it
QRectF FakeKeyboard::keyboardRect() const
{
    return m_visible ? m_rect : QRectF();
}

void FakeKeyboard::setVisible(bool visible)
{
    if (visible == m_visible)
        return;

    m_visible = visible;
    emitInputPanelVisibleChanged();
    emitKeyboardRectChanged();
    emit changed();
}
