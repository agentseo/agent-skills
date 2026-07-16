---
name: yandex-direct-combinatorial-ads
description: Use when creating or editing text ads in Yandex Direct via API v5 (Ads.add / Ads.update). Since mid-2025 classic TextAd is replaced by combinatorial "ResponsiveAd" — 1–7 titles and 1–3 texts the system auto-combines. Symptoms — Title2 ignored/dropped, "second headline" missing, ad created as RESPONSIVE_AD, need multiple headlines/texts/variants, overlong title silently omitted.
---

# Yandex Direct — combinatorial ads (ResponsiveAd) via API v5

## Overview

Classic `TextAd` (one Title + one Title2 + one Text) is deprecated. New text ads in Search / ЕПК campaigns are **combinatorial** (`ResponsiveAd`): supply **1–7 titles** and **1–3 texts**; Yandex assembles and tests the combinations automatically. `Ads.add` with a `TextAd` body now silently creates a `RESPONSIVE_AD`.

Two consequences that break old habits:

- **There is no `Title2`.** Extra headlines are just more `Titles` entries.
- **There is no pinning.** You cannot fix a title/text to a position — the algorithm picks. Design titles to read well in any combination.
- **Use the `v501` endpoint, not `v5`.** ResponsiveAd is served by the versioned Ads endpoint — call `https://api.direct.yandex.com/json/v501/ads` for add/get/delete/update. `v5` returns `Code 3500 "Не поддерживается ... используйте v501"`. (`get`/`delete` accept the ad on either version, but keep everything on v501 to avoid surprises.)

Transition ([update-tga](https://yandex.ru/dev/direct/doc/ru/update-tga)): since 30.06.2025 text-graphic ads are edit-only; since 14.07.2025 existing TextAds auto-convert (stats & ad number kept; a legacy Title2 is merged into Title via `". "` only if the total ≤56 chars, else it is lost).

## Structure: `AdAddItem.ResponsiveAd` (`ResponsiveAdAdd`)

Attach the Ad to an **`AdGroupId`** (not CampaignId). Ref: [Ads.add](https://yandex.ru/dev/direct/doc/ref-v5/ads/add.html).

| Field                                             | Type                | Required                   | Limit                                                                  |
| ------------------------------------------------- | ------------------- | -------------------------- | ---------------------------------------------------------------------- |
| `Titles`                                          | array&lt;string&gt; | **yes**                    | **1–7** items; each ≤**56** chars (incl. «narrow»); each word ≤**22**  |
| `Texts`                                           | array&lt;string&gt; | **yes**                    | **1–3** items; each ≤**81** + up to **15** «narrow»; each word ≤**23** |
| `Href`                                            | string              | `Href` **or** `BusinessId` | ≤1024                                                                  |
| `DisplayUrlPath`                                  | string              | no                         | ≤20, **only with `Href`**                                              |
| `SitelinkSetId`                                   | long                | no                         | **only with `Href`**                                                   |
| `AdExtensionIds`                                  | array&lt;long&gt;   | no                         | ≤50 (callouts / уточнения)                                             |
| `AdImageHashes`                                   | array&lt;string&gt; | no                         | 1–5 images (plural — no single `AdImageHash`)                          |
| `VideoExtensionIds`                               | array&lt;long&gt;   | no                         | 1–6                                                                    |
| `PriceExtension`, `AgeLabel`, `ErirAdDescription` | —                   | no                         | —                                                                      |

**«Narrow» characters** = `! , . ; : "` (counted specially in the length rules above).

## Payload example (`Ads.add`)

```json
{
  "method": "add",
  "params": {
    "Ads": [
      {
        "AdGroupId": 123456,
        "ResponsiveAd": {
          "Titles": [
            "Мультиметр RGK DM-10",
            "Мультиметры RGK — дилер",
            "Купить с доставкой по РФ",
            "Гарантия производителя",
            "Опт и розница, счёт юрлицам"
          ],
          "Texts": [
            "Цифровые мультиметры RGK. Наличие на складе, доставка по всей России.",
            "Официальный дилер RGK. Гарантия, опт и розница, отгрузка юрлицам."
          ],
          "Href": "https://example.ru/shop/multimetri-RGK-DM-10/",
          "DisplayUrlPath": "Мультиметры",
          "SitelinkSetId": 1491857899,
          "AdExtensionIds": [43484547, 35408314]
        }
      }
    ]
  }
}
```

## Best practices (Yandex help, quoted)

- «Добавьте максимальное количество заголовков и текстов и сделайте их разнообразными» — aim for 5–7 **diverse** titles + 3 texts. Different angles (brand · price/availability · delivery · guarantee · audience/opt), NOT rephrasings of one line.
- Up to **3** active combinatorial ads per group (10 incl. archived).
- No pinning → put the key phrase / model into **several** titles to raise the odds it shows.
- **Every title must contain the product name / query keyword** (`{type}`/`{model}` + a modifier like купить/цена/в наличии/доставка/оптом). Diversity comes from the modifiers, not from dropping the keyword. Generic sales lines with no keyword (delivery, guarantee, wholesale, "invoice for legal entities") belong in `Texts` and callouts, **not** in a title — a keyword-less title costs relevance and CTR.

## Common mistakes

- **Using `Title2`** — it does not exist in ResponsiveAd. Put every headline into `Titles`.
- **Overlong string silently dropped** — the API returns success but omits an over-limit title/text (observed: a 34-char "Title2" vanished at the 30-char classic limit). Validate every string against the limits _before_ sending; don't trust a 200 to mean all strings stuck. Re-`get` and count.
- **Word too long** — a single word >22 (titles) / >23 (texts) chars is rejected (e.g. long model slugs / URLs inside a title).
- **`DisplayUrlPath` / `SitelinkSetId` without `Href`** — both require `Href`.
- **Expecting pinning** — unsupported; every title must make sense in any combo.
- **Extensions on update** — `AdExtensionIds` are set at `Ads.add`; `Ads.update` may not (re)attach them the same way. Set callouts/sitelinks at creation.

## Migrating existing TextAds to full combinatorial

Ads created as `TextAd` become `RESPONSIVE_AD` with just 1 title (+ merged Title2) and 1 text. To enrich them into full 7-title / 3-text ads, `Ads.update` the `ResponsiveAd.Titles` / `.Texts` arrays, or delete+recreate. Prefer update to preserve statistics.
