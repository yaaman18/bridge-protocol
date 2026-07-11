# BRIDGE PROTOCOL RESTRICTED SOURCE-AVAILABLE LICENSE v1.0
# Bridge Protocol 限定ソースアベイラブル・ライセンス v1.0

Copyright © 2026 Mitsuyuki Yamaguchi / 山口光行. All rights reserved. 無断転載を禁じます。

Work covered / 対象著作物: the theory, formal specification documents, Lean sources, reference models, protocols, diagrams, and all accompanying text of the "Bridge Protocol" project (the "Work"). The Lean namespace and Julia package retain the identifier "ERIEC" for technical continuity. / 「Bridge Protocol」プロジェクトの理論、形式仕様文書、Lean ソース、参照モデル、プロトコル、図表、および付随する一切の文章(以下「本著作物」)。Lean 名前空間および Julia パッケージは技術的継続性のため「ERIEC」識別子を保持する。

---

> **NOTE / 注記.** This is a *source-available* license, **not** an open-source license. The source is disclosed for inspection, verification, and citation. It does **not** grant the freedoms of an OSI-approved license. / 本ライセンスは*ソースアベイラブル*ライセンスであり、オープンソースライセンス**ではありません**。ソースは閲覧・検証・引用のために開示されますが、OSI 承認ライセンスが与える諸自由は付与されません。

---

## EN — English (governing / 正文)

### 0. Definitions
- **"Work"**: everything defined above, in any version or partial form.
- **"You"**: any individual or legal entity exercising rights under this License.
- **"Verification"**: reading, compiling, type-checking, running the reference models, and independently reproducing the stated results, **without redistribution or derived use**.
- **"Derivative"**: any translation, adaptation, extension, reimplementation, or work that incorporates or is based on any part of the Work.
- **"Commercial Use"**: any use intended for or resulting in commercial advantage or monetary compensation, including paid services, products, consulting, or internal use by a for-profit entity in the course of its business.
- **"Certification Claim"**: any public statement that a system, model, artifact, person, or theory has "passed," is "certified by," "audited under," "compliant with," or "verified by" ERIEC or its protocols.

### 1. Grant of Verification Rights (only)
Subject to full compliance with this License, the Author grants You a worldwide, royalty-free, non-exclusive, **non-transferable, revocable** license to:
(a) access and read the Work;
(b) compile, type-check, and execute the Work **solely for Verification**;
(c) quote limited excerpts for academic citation, review, or commentary, provided the attribution in §4 is included.

**No other rights are granted.** All rights not expressly granted are reserved by the Author.

### 2. Prohibitions (strict)
Without a separate, signed, written agreement from the Author, You must **NOT**:
1. use the Work, in whole or in part, for any **Commercial Use**;
2. create, distribute, publish, or deploy any **Derivative**;
3. redistribute, host, mirror, or sublicense the Work, except an unmodified reference to the canonical repository URL;
4. remove, alter, or obscure any copyright, attribution, tag (`[DEF] [THM] [FLD] [OBL] [CNJ] [OUT] ‡ [META]`), provenance record, tombstone, or the reconstruction/‡ ledger;
5. make any **Certification Claim**, or represent any output as an ERIEC audit, certificate, or endorsement;
6. train, fine-tune, or distill any machine-learning model on the Work, or include the Work in any training corpus;
7. present the Work, or any restatement of it, as Your own, or as arising independently of the Author;
8. use the Author's name, the "ERIEC" name, or associated marks for endorsement or promotion.

### 3. Integrity of the Work
The Work encodes an epistemic discipline: the separation of proven statements, assumptions, frozen wagers, and reconstructions. Any use that **misrepresents this separation** — in particular, presenting a frozen wager (`W₁–W₆`, `[CNJ]`) or a bridge assumption as a proven result — is a material breach, independent of §2. Certification Claims are governed by §2.5 and §3 jointly.

### 4. Attribution (mandatory in all permitted uses)
Every permitted quotation or reference must include: (a) the title "ERIEC" and version; (b) "© 2026 Mitsuyuki Yamaguchi"; (c) a link to the canonical repository; (d) a statement that the Work is licensed under the ERIEC Restricted Source-Available License v1.0; (e) if a specific claim is cited, its tag (e.g. `[THM]`, `[CNJ]‡`) preserved verbatim.

### 5. Copyright
The Author asserts all economic and moral rights in the Work to the fullest extent permitted by applicable law, including the right of attribution and the right to integrity of the Work. Nothing herein transfers or exhausts any copyright.

### 6. No Warranty; No Reliance
THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. It is a research artifact. It is **not** advice — medical, psychiatric, legal, financial, safety, or otherwise — and **not** a certification instrument. No output constitutes a guarantee about any real system, person, or phenomenon. The Author is not liable for any use or consequence.

### 7. Termination
This License and all rights under it terminate **automatically and immediately** upon any breach, without notice. Upon termination You must cease all use and destroy all copies. Sections 2–6, 8 survive termination. The Author may also revoke the grant at will for any future version.

### 8. Governing Law; Separate Terms
This License is governed by the laws of Japan (or, at the Author's election, the Author's domicile), without regard to conflict-of-laws rules. Any Commercial Use, Derivative, or Certification requires a separate written agreement; contact: [CONTACT]. If any provision is unenforceable, the remainder stays in force, and the unenforceable provision is narrowed to the minimum extent necessary.

**By accessing the Work, You accept this License. If You do not accept, do not access, compile, or use the Work.**

---

## JA — 日本語(参考訳 / reference translation)

> 英語版を正文とし、齟齬がある場合は英語版が優先します。

### 0. 定義
- **「本著作物」**: 冒頭に定義した一切。版・部分を問わない。
- **「利用者」**: 本ライセンスに基づき権利を行使する個人または法人。
- **「検証」**: 閲覧、コンパイル、型検査、参照モデルの実行、および記載された結果の独立再現をいい、**再配布および派生利用を含まない**。
- **「派生物」**: 翻訳、翻案、拡張、再実装、または本著作物の一部を組み込みもしくは基礎とする一切の著作物。
- **「商用利用」**: 商業的利益または金銭的対価を目的とし、もしくは結果する一切の利用。有償役務・製品・コンサルティング、および営利法人による事業上の内部利用を含む。
- **「認証主張」**: あるシステム、モデル、成果物、人物、または理論が ERIEC もしくはそのプロトコルに「合格した」「認証された」「監査された」「準拠する」「検証された」旨の公表。

### 1. 検証権のみの許諾
本ライセンスの完全な遵守を条件として、著作者は利用者に対し、全世界・無償・非独占・**譲渡不能・撤回可能**の権利として、以下のみを許諾する:
(a) 本著作物へのアクセスおよび閲覧;
(b) **検証のためにのみ**行うコンパイル・型検査・実行;
(c) 第4条の帰属表示を付した上での、学術的引用・書評・論評のための限定的な抜粋の引用。

**その他一切の権利は許諾されない。** 明示的に許諾されない権利はすべて著作者が留保する。

### 2. 禁止事項(厳格)
著作者による個別の署名済み書面合意がない限り、利用者は以下を行っては**ならない**:
1. 本著作物の全部または一部を**商用利用**すること;
2. **派生物**を作成・配布・公表・展開すること;
3. 正規リポジトリ URL への無改変の参照を除き、本著作物を再配布・ホスト・ミラー・サブライセンスすること;
4. 著作権表示、帰属表示、タグ(`[DEF] [THM] [FLD] [OBL] [CNJ] [OUT] ‡ [META]`)、来歴記録、墓標、再構成・‡ 台帳を、削除・改変・隠蔽すること;
5. **認証主張**を行い、または出力を ERIEC の監査・証書・推奨として表示すること;
6. 本著作物を用いて機械学習モデルを訓練・微調整・蒸留し、または本著作物を訓練コーパスに含めること;
7. 本著作物またはその言い換えを、自己の成果として、もしくは著作者と独立に生じたものとして提示すること;
8. 推奨・宣伝のために著作者名、「ERIEC」名、または関連標章を用いること。

### 3. 著作物の完全性
本著作物は、証明済み言明・仮定・凍結された賭け・再構成の区別という認識論的規律を体現する。この区別を**誤って表示する**利用——とりわけ凍結された賭け(`W₁–W₆`、`[CNJ]`)や橋渡し仮定を証明済みの結果として提示すること——は、第2条とは独立に重大な違反を構成する。

### 4. 帰属表示(許諾されるすべての利用で必須)
許諾される引用・参照には必ず次を含めること: (a) 表題「ERIEC」および版; (b)「© 2026 山口光行」; (c) 正規リポジトリへのリンク; (d) 本著作物が ERIEC 限定ソースアベイラブル・ライセンス v1.0 の下にある旨; (e) 特定の言明を引用する場合、そのタグ(例 `[THM]`、`[CNJ]‡`)を逐語で保持すること。

### 5. 著作権
著作者は、適用法が許す最大限において、帰属権および同一性保持権を含む本著作物の一切の財産的・人格的権利を主張する。本ライセンスは著作権を移転せず、また消尽させない。

### 6. 無保証・非依拠
本著作物は「現状有姿」で提供され、いかなる保証も伴わない。これは研究上の成果物である。医療・精神医学・法務・財務・安全その他の**助言ではなく**、**認証手段でもない**。いかなる出力も、現実のシステム・人物・現象についての保証を構成しない。著作者は一切の利用および結果について責任を負わない。

### 7. 終了
本ライセンスおよびその下の一切の権利は、いかなる違反によっても、通知なく**自動的かつ即時に**終了する。終了時、利用者はすべての利用を停止し、すべての複製を破棄しなければならない。第2条〜第6条・第8条は終了後も存続する。著作者は将来の版について随意に許諾を撤回できる。

### 8. 準拠法・別途条件
本ライセンスは日本法(または著作者の選択により著作者の住所地法)に準拠し、抵触法の規則を適用しない。商用利用・派生物・認証には別途の書面合意を要する。連絡先: [CONTACT]。いずれかの条項が執行不能な場合も残余は有効に存続し、当該条項は必要最小限に限定して解釈される。

「将来別途公開される応用プロトコルは、各々が個別に指定するライセンスに従い、本ライセンスの制限は及ばない」

**本著作物にアクセスした時点で、利用者は本ライセンスに同意したものとみなす。同意しない場合は、アクセス・コンパイル・利用をしてはならない。**
