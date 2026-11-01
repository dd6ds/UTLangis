// vCard reading, see vcard.h. Only what a contact pick needs: the display
// name (FN, else N) and the phone numbers (TEL).

#include "vcard.h"

#include <QByteArray>
#include <QFile>
#include <QList>

namespace {

// Long lines continue on the next line, which then starts with a space or tab.
QList<QByteArray> unfoldedLines(const QByteArray &data)
{
    QList<QByteArray> lines;
    for (QByteArray line : data.split('\n')) {
        if (line.endsWith('\r'))
            line.chop(1);
        if (!lines.isEmpty() && (line.startsWith(' ') || line.startsWith('\t')))
            lines.last().append(line.mid(1));
        else
            lines.append(line);
    }
    return lines;
}

// vCard 2.1 may encode values as quoted-printable ("M=C3=BCller").
QByteArray decodeQuotedPrintable(const QByteArray &value)
{
    QByteArray decoded;
    for (int i = 0; i < value.size(); ++i) {
        if (value.at(i) == '=' && i + 2 < value.size()) {
            bool ok = false;
            const int byte = value.mid(i + 1, 2).toInt(&ok, 16);
            if (ok) {
                decoded.append(static_cast<char>(byte));
                i += 2;
                continue;
            }
        }
        decoded.append(value.at(i));
    }
    return decoded;
}

// vCard 3.0/4.0 escape commas, semicolons and backslashes in values.
QString unescape(const QString &value)
{
    QString text;
    for (int i = 0; i < value.size(); ++i) {
        if (value.at(i) == QLatin1Char('\\') && i + 1 < value.size()) {
            const QChar next = value.at(++i);
            text.append(next == QLatin1Char('n') || next == QLatin1Char('N')
                        ? QStringLiteral(" ") : QString(next));
        } else {
            text.append(value.at(i));
        }
    }
    return text.trimmed();
}

// "N:Family;Given;Middle;Prefix;Suffix" as "Given Family".
QString nameFromN(const QString &value)
{
    const QStringList parts = value.split(QLatin1Char(';'));
    QStringList name;
    if (parts.size() > 1 && !parts.at(1).trimmed().isEmpty())
        name.append(unescape(parts.at(1)));
    if (!parts.at(0).trimmed().isEmpty())
        name.append(unescape(parts.at(0)));
    return name.join(QLatin1Char(' '));
}

} // namespace

VCardContact parseVCard(const QByteArray &data)
{
    VCardContact contact;
    QString nameFromNField;
    for (const QByteArray &line : unfoldedLines(data)) {
        const int colon = line.indexOf(':');
        if (colon <= 0)
            continue;
        // "item1.TEL;TYPE=CELL" -> property "TEL", parameters after ';'.
        const QByteArray head = line.left(colon).toUpper();
        QByteArray property = head.split(';').first();
        property = property.mid(property.lastIndexOf('.') + 1);
        QByteArray raw = line.mid(colon + 1);
        if (head.contains("QUOTED-PRINTABLE"))
            raw = decodeQuotedPrintable(raw);
        const QString value = QString::fromUtf8(raw);

        if (property == "END")
            break;
        if (property == "FN" && contact.name.isEmpty())
            contact.name = unescape(value);
        else if (property == "N")
            nameFromNField = nameFromN(value);
        else if (property == "TEL") {
            QString number = unescape(value);
            if (number.startsWith(QLatin1String("tel:"), Qt::CaseInsensitive))
                number = number.mid(4);
            if (!number.isEmpty() && !contact.numbers.contains(number))
                contact.numbers.append(number);
        }
    }
    if (contact.name.isEmpty())
        contact.name = nameFromNField;
    return contact;
}

VCardContact readVCardFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const VCardContact contact = parseVCard(file.readAll());
    file.close();
    file.remove();
    return contact;
}
