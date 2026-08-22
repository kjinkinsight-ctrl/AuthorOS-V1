# Bundled typefaces

Two families, four weights each, all under the SIL Open Font License 1.1.

| File | Family | Weight | Style |
|---|---|---|---|
| `Merriweather-400.ttf` | Merriweather | 400 | upright |
| `Merriweather-700.ttf` | Merriweather | 700 | upright |
| `Merriweather-400-Italic.ttf` | Merriweather | 400 | italic |
| `Merriweather-700-Italic.ttf` | Merriweather | 700 | italic |
| `Inter-400.ttf` | Inter | 400 | upright |
| `Inter-700.ttf` | Inter | 700 | upright |
| `Inter-400-Italic.ttf` | Inter | 400 | italic |
| `Inter-700-Italic.ttf` | Inter | 700 | italic |

**Merriweather** is by Sorkin Type (Eben Sorkin), and **Inter** is by Rasmus
Andersson. Both are published under the SIL Open Font License, Version 1.1,
which permits bundling and redistribution inside an application.

## Provenance

Every file here is an **unmodified** static release from Google Fonts,
redistributed by the `@expo-google-fonts/merriweather` and
`@expo-google-fonts/inter` packages. Nothing was subsetted, re-encoded, renamed
or otherwise altered.

That matters legally as well as technically. Merriweather is licensed **with the
Reserved Font Name "Merriweather"**, and the OFL defines a Modified Version as
any derivative made *"by adding to, deleting, or substituting … any of the
components of the Original Version, by changing formats or by porting the Font
Software to a new environment"* — which a subset or a WOFF2-to-TrueType
conversion plainly is, and which clause 3 then forbids from carrying the
reserved name. Shipping the originals keeps that question from arising at all.

It also happens to give the better result: each italic carries the full glyph
set rather than a Latin subset, so an accented or Central European character
inside an emphasised phrase renders instead of falling back.

The weight class, units per em, ascent and descent of each italic match its
upright exactly, which is what lets an emphasised run sit on the same baseline
with the same leading as the prose around it.

## Size

The four italics add roughly 2.8 MB, of which the two Merriweather faces are
most — they carry more glyphs than the uprights they accompany, which is the
price of shipping them unmodified.

Nothing is paid for it until Book Studio opens. `BookFontAssets.load()` is the
only thing that touches these files, it caches for the session, and nothing on
the path to first paint calls it.

## SIL Open Font License 1.1

    Copyright (c) Sorkin Type Co (Merriweather)
    Copyright (c) The Inter Project Authors (Inter)

    This Font Software is licensed under the SIL Open Font License, Version 1.1.

    PREAMBLE

    The goals of the Open Font License (OFL) are to stimulate worldwide
    development of collaborative font projects, to support the font creation
    efforts of academic and linguistic communities, and to provide a free and
    open framework in which fonts may be shared and improved in partnership with
    others.

    The OFL allows the licensed fonts to be used, studied, modified and
    redistributed freely as long as they are not sold by themselves. The fonts,
    including any derivative works, can be bundled, embedded, redistributed
    and/or sold with any software provided that any reserved names are not used
    by derivative works. The fonts and derivatives, however, cannot be released
    under any other type of license. The requirement for fonts to remain under
    this license does not apply to any document created using the fonts or their
    derivatives.

    PERMISSION & CONDITIONS

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of the Font Software, to use, study, copy, merge, embed, modify,
    redistribute, and sell modified and unmodified copies of the Font Software,
    subject to the following conditions:

    1) Neither the Font Software nor any of its individual components, in
    Original or Modified Versions, may be sold by itself.

    2) Original or Modified Versions of the Font Software may be bundled,
    redistributed and/or sold with any software, provided that each copy
    contains the above copyright notice and this license. These can be included
    either as stand-alone text files, human-readable headers or in the
    appropriate machine-readable metadata fields within text or binary files as
    long as those fields can be easily viewed by the user.

    3) No Modified Version of the Font Software may use the Reserved Font
    Name(s) unless explicit written permission is granted by the corresponding
    Copyright Holder. This restriction only applies to the primary font name as
    presented to the users.

    4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
    Software shall not be used to promote, endorse or advertise any Modified
    Version, except to acknowledge the contribution(s) of the Copyright
    Holder(s) and the Author(s) or with their explicit written permission.

    5) The Font Software, modified or unmodified, in part or in whole, must be
    distributed entirely under this license, and must not be distributed under
    any other license. The requirement for fonts to remain under this license
    does not apply to any document created using the Font Software.

    TERMINATION

    This license becomes null and void if any of the above conditions are not
    met.

    DISCLAIMER

    THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT,
    TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE
    FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL,
    INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF
    CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT
    SOFTWARE.
