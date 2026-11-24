#include "ui/accessibility.h"

#include "core/diagnostics.h"

#include <inkview.h>
#include <inkview/accessibility_text.h>
#include <QFont>
#include <QGuiApplication>
#include <common_utilities/einkinterface.h>

using pocketbook::utilities::einkPlatform;

Accessibility::Accessibility(QObject *parent)
    : QObject(parent)
{
    reload();
}

void Accessibility::followChanges()
{
    auto *platform = einkPlatform();
    if (!platform)
        return;
    platform->addHandlerForInkvewEvents([this](int type, int, int) {
        if (type == EVT_CONFIGCHANGED)
            QMetaObject::invokeMethod(this, &Accessibility::reload, Qt::QueuedConnection);
    });
}

void Accessibility::reload()
{
    // The slider goes from 100 to 200
    const qreal textScale = qBound(100, iv_text_scale_percentage(), 200) / 100.0;
    const bool boldText = iv_text_bold_enabled();
    const bool highContrast = iv_text_contrast_enabled();
    const QString fontFamily = QString::fromUtf8(iv_get_default_font(FONT_FAMILY));
    if (textScale == m_textScale && boldText == m_boldText && highContrast == m_highContrast
            && fontFamily == m_fontFamily)
        return;

    m_textScale = textScale;
    m_boldText = boldText;
    m_highContrast = highContrast;
    m_fontFamily = fontFamily;
    diagnostics::log(QString("text size %1, bold %2, contrast %3, font %4")
                         .arg(m_textScale).arg(m_boldText).arg(m_highContrast).arg(m_fontFamily));

    // For anything that doesn't set its own, such as the keyboard's text fields
    QFont font = QGuiApplication::font();
    font.setFamily(m_fontFamily);
    QGuiApplication::setFont(font);
    emit changed();
}
