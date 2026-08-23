// pr-assets ブランチの `pr-<番号>/manifest.json` を読み、機能ごとの最新デモ（動画）と
// 画面ごとの最新スクリーンショットを `features/<機能>/` へコピーして索引 `features/README.md` を
// 再生成する（conventions/pr-assets.md「機能カタログ」）。
//
// 実行: node scripts/build-demo-catalog.ts --assets-dir <pr-assets の作業コピー> --pr <番号>
//
// Why not: 依存を一切使わない（zod も tsx も）。このスクリプトは pr-assets への書き込み権限を
// 持つ唯一のジョブから実行されるため、`pnpm install` を挟むと lifecycle script が書き込み
// トークンを持つ環境で動く。node 標準 API だけで書き、Node の型ストリップで直接実行する。
//
// 書き込むのは features/ 配下だけ。pr-<番号>/ は読み取り専用（過去 PR のリンクが張られている）で、
// ルートの README.md は人が書くもの（同ドキュメント）なので触らない。
//
// 既知の制約: merge 順とワークフローの実行順が逆転すると、一時的に古い方のデモが「最新」として
// 並ぶ。次回その機能が更新された時点で正しくなる自己修復的な不整合なので、順序制御はしていない。
import fs from "node:fs";
import path from "node:path";

const REPO = "MizuRyu/NightCorePlayer";
const ASSETS_BRANCH = "pr-assets";
const FEATURES_DIR_NAME = "features";
const SCREENS_DIR_NAME = "screens";
const META_FILE_NAME = "meta.json";
const README_FILE_NAME = "README.md";
const GENERATOR = "scripts/build-demo-catalog.ts";

// コピー先のファイル名は固定する。元の名前を引き継ぐと、名前が変わる更新
// （daily-log.gif → daily-log-v2.gif）のたびに旧ファイルが孤児として残り、
// 「features/<機能>/ は常に最新のデモ」という不変条件が崩れるため。
const CATALOG_GIF_NAME = "demo.gif";
const CATALOG_MP4_NAME = "demo.mp4";

/** ディレクトリ名・ロール名に許す文字。`..` や `/` の混入を入口で断つ。 */
const SLUG_PATTERN = /^[a-z0-9-]+$/;

/**
 * 画面キーの部品（screen / state）に許す文字。SLUG_PATTERN より狭く、連続ハイフンと
 * 先頭・末尾のハイフンを禁じる。`<screen>--<state>` で組み立てるキーが単射でなくなると、
 * screen="a--b" と screen="a" state="b" が同じキーに潰れ、別の画面を上書き・削除してしまう。
 */
const SCREEN_SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

/** 昇格日。`YYYY-MM-DD` だけを許し、索引にそのまま埋め込む。 */
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

/**
 * スクショに許す拡張子。
 * Why not: 動画のように `demo.gif` へ名前を固定しない（拡張子を揃えるには変換が必要で、
 * 依存なしでは書けない）。代わりに画面キーで名前を決め、拡張子が変わったら旧ファイルを消す。
 */
const SCREENSHOT_EXTENSIONS = [".png", ".jpg", ".jpeg", ".webp"] as const;

export interface DemoManifestEntry {
  feature: string;
  title: string;
  roles: string[];
  gif: string;
  mp4: string;
}

/**
 * 手撮りのスクショ1枚。動画がストーリーを見せるのに対し、こちらは画面・状態のカット
 * （empty / error / dialog 等）を見せる。`screen` + `state` が「どの画面のどの状態か」の
 * 識別子で、この単位で最新版に差し替える。
 */
export interface DemoManifestScreenshot {
  feature: string;
  screen: string;
  /** 状態の区別が不要な画面では null（`<screen>.png` として昇格する）。 */
  state: string | null;
  file: string;
  caption: string;
}

export interface DemoManifest {
  /**
   * 録画は PR を作る前に走るため、この時点では番号が無い（record-demo.ts は `--pr` 未指定で
   * null を書く）。権威は「どの pr-<番号>/ から読んだか」であり、ここは参考情報にすぎない。
   */
  prNumber: number | null;
  entries: DemoManifestEntry[];
  /** 未指定の manifest（動画だけの PR・スクショ機能より前に作られたもの）では空配列。 */
  screenshots: DemoManifestScreenshot[];
}

/**
 * 動画とその出典。スクショだけが載っている機能では丸ごと欠けるため、
 * 「全部あり or 全部なし」を型で表す（title だけある meta のような中間状態を作らない）。
 */
export interface FeatureVideo {
  title: string;
  roles: string[];
  gif: string;
  mp4: string;
  prNumber: number;
}

/** 昇格済みのスクショ1枚。出典 PR と昇格日を持たせ、索引で古さが見えるようにする。 */
export interface FeatureScreen {
  screen: string;
  state: string | null;
  file: string;
  caption: string;
  prNumber: number;
  promotedAt: string;
}

/**
 * `features/<機能>/meta.json`。索引はこれだけを読んで再生成する（README を逆パースしない）。
 * JSON 上は動画系フィールドが平坦に並ぶ（`{feature, title, roles, gif, mp4, prNumber, screens}`）。
 * 既存ファイルとの互換のため形は変えず、読み書きの境界で video へ束ね直している。
 */
export interface FeatureMeta {
  feature: string;
  video: FeatureVideo | null;
  screens: FeatureScreen[];
}

export interface CatalogPlan {
  copies: { from: string; to: string }[];
  /** 同じ画面キーで拡張子が変わったときの旧ファイル（参照されない画像を screens/ に残さない）。 */
  deletions: string[];
  metaWrites: { path: string; meta: FeatureMeta }[];
  readme: { path: string; content: string } | null;
}

function fail(message: string): never {
  throw new Error(message);
}

function asRecord(value: unknown, label: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    fail(`${label} がオブジェクトではない`);
  }
  return value as Record<string, unknown>;
}

function requireSlug(value: unknown, label: string): string {
  if (typeof value !== "string" || !SLUG_PATTERN.test(value)) {
    fail(`${label} は ${SLUG_PATTERN.source} に一致する必要がある: ${JSON.stringify(value)}`);
  }
  return value;
}

function requireScreenSlug(value: unknown, label: string): string {
  if (typeof value !== "string" || !SCREEN_SLUG_PATTERN.test(value)) {
    fail(
      `${label} は ${SCREEN_SLUG_PATTERN.source} に一致する必要がある: ${JSON.stringify(value)}`,
    );
  }
  return value;
}

/** 状態（empty / error 等）は任意。未指定と「状態の区別なし」を同じ null に寄せる。 */
function requireOptionalScreenSlug(value: unknown, label: string): string | null {
  if (value === null || value === undefined) return null;
  return requireScreenSlug(value, label);
}

function requireDate(value: unknown, label: string): string {
  if (typeof value !== "string" || !DATE_PATTERN.test(value)) {
    fail(`${label} は YYYY-MM-DD でなければならない: ${JSON.stringify(value)}`);
  }
  return value;
}

/**
 * ファイル名として安全であることを確認する。パス区切り・`..` を弾いた上で拡張子まで固定し、
 * pr-<番号>/ の外を読ませない・features/<機能>/ の外へ書かせない。
 */
function requireFileName(value: unknown, extension: string, label: string): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(value)) {
    fail(`${label} がファイル名として不正: ${JSON.stringify(value)}`);
  }
  if (value.includes("..") || value.includes("/") || value.includes("\\")) {
    fail(`${label} にパス区切りまたは .. が含まれる: ${value}`);
  }
  if (!value.endsWith(extension)) {
    fail(`${label} の拡張子は ${extension} でなければならない: ${value}`);
  }
  return value;
}

/** 許可拡張子のどれで終わるかを返す。コピー先はこの拡張子をそのまま引き継ぐ。 */
function screenshotExtension(file: string, label: string): string {
  const extension = SCREENSHOT_EXTENSIONS.find((candidate) => file.endsWith(candidate));
  if (extension === undefined) {
    fail(
      `${label} の拡張子は ${SCREENSHOT_EXTENSIONS.join(" / ")} のいずれかでなければならない: ${file}`,
    );
  }
  return extension;
}

function requireScreenshotFileName(value: unknown, label: string): string {
  if (typeof value !== "string") {
    fail(`${label} がファイル名として不正: ${JSON.stringify(value)}`);
  }
  return requireFileName(value, screenshotExtension(value, label), label);
}

/** 索引 Markdown へそのまま埋め込む文字列。改行・記号での構造破壊を防ぐ。 */
function requireTitle(value: unknown, label: string): string {
  if (typeof value !== "string" || value.trim() === "") {
    fail(`${label} が空`);
  }
  if (/[\r\n]/.test(value)) {
    fail(`${label} に改行が含まれる`);
  }
  return value.trim();
}

/**
 * Why not: 空配列を弾かない。このスクリプトが走るのは merge された後で、ここで落としても
 * PR をやり直せない（ロール未検出は索引の見栄えの問題でしかない）。録画時点で落とすべき
 * 検証は録画スクリプト側に置く。パストラバーサル系は事後でも落とすべきなので厳格なまま。
 */
function requireRoles(value: unknown, label: string): string[] {
  if (!Array.isArray(value)) {
    fail(`${label} が配列ではない`);
  }
  return value.map((role, index) => requireSlug(role, `${label}[${index}]`));
}

function requirePrNumber(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
    fail(`${label} は正の整数でなければならない: ${JSON.stringify(value)}`);
  }
  return value;
}

function parseEntry(raw: unknown, label: string): DemoManifestEntry {
  const entry = asRecord(raw, label);
  return {
    feature: requireSlug(entry.feature, `${label}.feature`),
    title: requireTitle(entry.title, `${label}.title`),
    roles: requireRoles(entry.roles, `${label}.roles`),
    gif: requireFileName(entry.gif, ".gif", `${label}.gif`),
    mp4: requireFileName(entry.mp4, ".mp4", `${label}.mp4`),
  };
}

function parseScreenshot(raw: unknown, label: string): DemoManifestScreenshot {
  const screenshot = asRecord(raw, label);
  return {
    feature: requireSlug(screenshot.feature, `${label}.feature`),
    screen: requireScreenSlug(screenshot.screen, `${label}.screen`),
    state: requireOptionalScreenSlug(screenshot.state, `${label}.state`),
    file: requireScreenshotFileName(screenshot.file, `${label}.file`),
    caption: requireTitle(screenshot.caption, `${label}.caption`),
  };
}

/**
 * 「どの画面のどの状態か」を1本の文字列にする。昇格先のファイル名（拡張子を除く）と同じで、
 * 上書き対象の突き合わせ・並び順の正規化もこのキーで行う。
 */
function screenKey(screen: { screen: string; state: string | null }): string {
  return screen.state === null ? screen.screen : `${screen.screen}--${screen.state}`;
}

export function parseDemoManifest(raw: unknown): DemoManifest {
  const manifest = asRecord(raw, "manifest");
  const prNumber =
    manifest.prNumber === null || manifest.prNumber === undefined
      ? null
      : requirePrNumber(manifest.prNumber, "manifest.prNumber");
  if (!Array.isArray(manifest.entries)) {
    fail("manifest.entries が配列ではない");
  }

  const entries = manifest.entries.map((entry, index) =>
    parseEntry(entry, `manifest.entries[${index}]`),
  );
  const features = new Set(entries.map((entry) => entry.feature));
  if (features.size !== entries.length) {
    fail("manifest.entries に同じ feature が重複している（どちらが最新か決められない）");
  }

  // screenshots は後から足した項目なので、未指定を空配列として扱う（既存の manifest を読めなくしない）。
  const rawScreenshots = manifest.screenshots ?? [];
  if (!Array.isArray(rawScreenshots)) {
    fail("manifest.screenshots が配列ではない");
  }
  const screenshots = rawScreenshots.map((screenshot, index) =>
    parseScreenshot(screenshot, `manifest.screenshots[${index}]`),
  );
  const screenKeys = new Set(screenshots.map((shot) => `${shot.feature}/${screenKey(shot)}`));
  if (screenKeys.size !== screenshots.length) {
    fail("manifest.screenshots に同じ機能・画面・状態が重複している（昇格先が衝突する）");
  }

  return { prNumber, entries, screenshots };
}

function parseFeatureScreen(raw: unknown, label: string): FeatureScreen {
  const screen = asRecord(raw, label);
  const parsed = {
    screen: requireScreenSlug(screen.screen, `${label}.screen`),
    state: requireOptionalScreenSlug(screen.state, `${label}.state`),
    file: requireScreenshotFileName(screen.file, `${label}.file`),
    caption: requireTitle(screen.caption, `${label}.caption`),
    prNumber: requirePrNumber(screen.prNumber, `${label}.prNumber`),
    promotedAt: requireDate(screen.promotedAt, `${label}.promotedAt`),
  };

  // 昇格したファイル名は画面キーそのもの。食い違う meta を信じると、ある画面の更新で
  // 別の画面の画像を「旧ファイル」として消してしまう。
  const expected = `${screenKey(parsed)}${screenshotExtension(parsed.file, `${label}.file`)}`;
  if (parsed.file !== expected) {
    fail(`${label}.file が画面キーと一致しない（${expected} のはず）: ${parsed.file}`);
  }
  return parsed;
}

/**
 * 動画系フィールドは「全部あり or 全部なし」。スクショだけの機能では丸ごと欠けるので
 * 不在を許すが、一部だけ欠けた meta は生成側の壊れ方なので落とす。
 */
function parseFeatureVideo(meta: Record<string, unknown>, label: string): FeatureVideo | null {
  const keys = ["title", "roles", "gif", "mp4", "prNumber"] as const;
  const present = keys.filter((key) => meta[key] !== undefined);
  if (present.length === 0) return null;
  if (present.length !== keys.length) {
    fail(`${label} の動画フィールドが揃っていない（あるのは ${present.join(", ")}）`);
  }

  return {
    title: requireTitle(meta.title, `${label}.title`),
    roles: requireRoles(meta.roles, `${label}.roles`),
    gif: requireFileName(meta.gif, ".gif", `${label}.gif`),
    mp4: requireFileName(meta.mp4, ".mp4", `${label}.mp4`),
    prNumber: requirePrNumber(meta.prNumber, `${label}.prNumber`),
  };
}

export function parseFeatureMeta(raw: unknown, label: string): FeatureMeta {
  const meta = asRecord(raw, label);
  const feature = requireSlug(meta.feature, `${label}.feature`);
  const video = parseFeatureVideo(meta, label);

  const rawScreens = meta.screens ?? [];
  if (!Array.isArray(rawScreens)) {
    fail(`${label}.screens が配列ではない`);
  }
  const screens = rawScreens.map((screen, index) =>
    parseFeatureScreen(screen, `${label}.screens[${index}]`),
  );
  if (new Set(screens.map(screenKey)).size !== screens.length) {
    fail(`${label}.screens に同じ画面・状態が重複している（どちらが最新か決められない）`);
  }

  // 中身の無い meta は索引に見出しだけを生む。生成側の不具合をここで止める。
  if (video === null && screens.length === 0) {
    fail(`${label} に動画もスクリーンショットも無い`);
  }

  return { feature, video, screens };
}

/** 解決後の絶対パスが features/ 配下に収まっていることを保証する多層防御の最終段。 */
function resolveInFeatures(featuresDir: string, ...segments: string[]): string {
  const resolved = path.resolve(featuresDir, ...segments);
  if (!resolved.startsWith(`${path.resolve(featuresDir)}${path.sep}`)) {
    fail(`書き込み先が features/ の外を指している: ${resolved}`);
  }
  return resolved;
}

function assetUrl(...segments: string[]): string {
  return `https://github.com/${REPO}/blob/${ASSETS_BRANCH}/${segments.join("/")}?raw=true`;
}

function pullRequestUrl(prNumber: number): string {
  return `https://github.com/${REPO}/pull/${prNumber}`;
}

/** CommonMark でエスケープが効く ASCII 記号のうち、索引の構造を壊しうるもの。 */
const MARKDOWN_PUNCTUATION = /[\\[\]()*_~`#+\-.!>|]/g;

/**
 * 索引に埋め込む自由文（タイトル・キャプション）を、記法として解釈されない1つの文字列にする。
 * これらはテスト名や人の手書きから来るので、記法を含みうる。
 *
 * Why not: 危ない記法を列挙して潰さない（行頭の `#` だけ、`]` だけ…）。`~~~` の未閉フェンス・
 * 行中の `![x](url)` のように後から穴が見つかり続けるため、意味を持つ記号を位置に関わらず
 * 全てバックスラッシュエスケープする。GitHub の描画では記号そのものとして出るので見た目は変わらない。
 * インライン HTML（`<!--` は以降のカタログ全体を不可視にする）だけはバックスラッシュが効かないので、
 * 先に実体参照へ逃がす。
 */
function escapeMarkdownText(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(MARKDOWN_PUNCTUATION, (character) => `\\${character}`);
}

function renderVideoBlock(dir: string, video: FeatureVideo): string[] {
  const roles = video.roles.map((role) => `\`${role}\``).join(" ");
  return [
    "",
    escapeMarkdownText(video.title),
    // ロール未検出のデモでも索引には載せる（空行だけの行を残さない）
    ...(roles === "" ? [] : ["", `ロール: ${roles}`]),
    "",
    `![${escapeMarkdownText(video.title)}](${assetUrl(dir, video.gif)})`,
    "",
    `[▶ フル解像度の動画（mp4）](${assetUrl(dir, video.mp4)}) ・ 出典: [#${video.prNumber}](${pullRequestUrl(video.prNumber)})`,
  ];
}

/** スクショは画面ごとに出典 PR と昇格日を添える（動画と更新タイミングが別なので古さが読めるように）。 */
function renderScreenBlock(dir: string, screen: FeatureScreen): string[] {
  return [
    "",
    `![${escapeMarkdownText(screen.caption)}](${assetUrl(dir, SCREENS_DIR_NAME, screen.file)})`,
    "",
    `${escapeMarkdownText(screen.caption)} ・ 出典: [#${screen.prNumber}](${pullRequestUrl(screen.prNumber)})（${screen.promotedAt}）`,
  ];
}

function renderFeatureSection(meta: FeatureMeta): string {
  const dir = `${FEATURES_DIR_NAME}/${meta.feature}`;
  return [
    `## ${meta.feature}`,
    ...(meta.video === null ? [] : renderVideoBlock(dir, meta.video)),
    ...meta.screens.flatMap((screen) => renderScreenBlock(dir, screen)),
  ].join("\n");
}

export function renderCatalogReadme(metas: FeatureMeta[]): string {
  // Why not: localeCompare で並べない（実行環境の ICU で順序が変わり、生成のたびに無駄な差分が出る）。
  const sorted = [...metas].sort((a, b) =>
    a.feature < b.feature ? -1 : a.feature > b.feature ? 1 : 0,
  );

  const sections = sorted.map(renderFeatureSection);
  const body = sections.length > 0 ? sections : ["まだ登録された機能デモはありません。"];

  return [
    `<!-- このファイルは ${GENERATOR} が自動生成する。手で編集しない（次の merge で上書きされる）。 -->`,
    "",
    "# 機能デモカタログ",
    "",
    "機能ごとの最新デモ（E2E のメインストーリーの録画）と、画面ごとの最新スクリーンショット。PR が merge されるたびに自動更新される。",
    // （docs/conventions/pr-assets.md はこのテンプレの conventions/pr-assets.md を配置した先）。
    `運用は [docs/conventions/pr-assets.md](https://github.com/${REPO}/blob/main/docs/conventions/pr-assets.md) を参照。`,
    "",
    ...body.flatMap((section, index) => (index === 0 ? [section] : ["", section])),
    "",
  ].join("\n");
}

/** Why not: localeCompare で並べない（実行環境の ICU で順序が変わり、生成のたびに無駄な差分が出る）。 */
function sortScreens(screens: FeatureScreen[]): FeatureScreen[] {
  return [...screens].sort((a, b) => {
    const [left, right] = [screenKey(a), screenKey(b)];
    return left < right ? -1 : left > right ? 1 : 0;
  });
}

export function planCatalogUpdate(input: {
  manifest: DemoManifest | null;
  /** 読み込み元 pr-<番号>/ の番号。manifest 内の prNumber ではなくこちらが権威。 */
  prNumber: number;
  existingMetas: FeatureMeta[];
  /** スクショの昇格日（`YYYY-MM-DD`）。生成を決定的にするため呼び出し側から渡す。 */
  promotedAt: string;
  assetsDir: string;
}): CatalogPlan {
  const { manifest, prNumber, existingMetas, promotedAt, assetsDir } = input;
  if (manifest === null) {
    return { copies: [], deletions: [], metaWrites: [], readme: null };
  }

  const featuresDir = path.join(assetsDir, FEATURES_DIR_NAME);
  const prDir = path.join(assetsDir, `pr-${prNumber}`);

  const copies: CatalogPlan["copies"] = [];
  const deletions: CatalogPlan["deletions"] = [];

  // 既存の meta を土台に、今回の manifest が触った部分（動画一式・該当画面キー）だけを差し替える。
  // 動画とスクショは別の PR で更新されるため、片方の更新でもう片方を落とさない。
  const catalog = new Map(existingMetas.map((meta) => [meta.feature, meta]));
  const touched = new Set<string>();
  const metaOf = (feature: string): FeatureMeta =>
    catalog.get(feature) ?? { feature, video: null, screens: [] };

  for (const entry of manifest.entries) {
    const featureDir = resolveInFeatures(featuresDir, entry.feature);
    const renamed = [
      [entry.gif, CATALOG_GIF_NAME],
      [entry.mp4, CATALOG_MP4_NAME],
    ] as const;
    for (const [sourceName, catalogName] of renamed) {
      copies.push({
        from: path.join(prDir, sourceName),
        to: resolveInFeatures(featureDir, catalogName),
      });
    }
    catalog.set(entry.feature, {
      ...metaOf(entry.feature),
      video: {
        title: entry.title,
        roles: entry.roles,
        gif: CATALOG_GIF_NAME,
        mp4: CATALOG_MP4_NAME,
        prNumber,
      },
    });
    touched.add(entry.feature);
  }

  for (const screenshot of manifest.screenshots) {
    const featureDir = resolveInFeatures(featuresDir, screenshot.feature);
    const screensDir = resolveInFeatures(featureDir, SCREENS_DIR_NAME);
    const key = screenKey(screenshot);
    const label = `screenshots(${screenshot.feature}/${key})`;
    const file = `${key}${screenshotExtension(screenshot.file, label)}`;
    copies.push({
      from: path.join(prDir, screenshot.file),
      to: resolveInFeatures(screensDir, file),
    });

    const current = metaOf(screenshot.feature);
    const previous = current.screens.find((screen) => screenKey(screen) === key);
    // 同じ画面キーでも拡張子が変わると別名で置かれ、旧ファイルは誰からも参照されなくなる。
    if (previous !== undefined && previous.file !== file) {
      deletions.push(resolveInFeatures(screensDir, previous.file));
    }
    // 同じ PR の同じ画像を昇格し直す（workflow_dispatch での再実行・push 競合のリトライ）
    // だけなら、実際に更新された日ではないので昇格日を据え置く。
    const unchanged = previous?.prNumber === prNumber && previous?.file === file;
    catalog.set(screenshot.feature, {
      ...current,
      screens: sortScreens([
        ...current.screens.filter((screen) => screenKey(screen) !== key),
        {
          screen: screenshot.screen,
          state: screenshot.state,
          file,
          caption: screenshot.caption,
          prNumber,
          promotedAt: unchanged ? previous.promotedAt : promotedAt,
        },
      ]),
    });
    touched.add(screenshot.feature);
  }

  const metaWrites = [...touched].map((feature) => ({
    path: resolveInFeatures(resolveInFeatures(featuresDir, feature), META_FILE_NAME),
    meta: metaOf(feature),
  }));

  return {
    copies,
    deletions,
    metaWrites,
    readme: {
      path: resolveInFeatures(featuresDir, README_FILE_NAME),
      content: renderCatalogReadme([...catalog.values()]),
    },
  };
}

// ここから下はファイルシステムに触る層。resolveInFeatures の字句チェックだけでは
// シンボリックリンクを見抜けない（`features/daily-log -> ../pr-123` は字句上 features/ 配下だが
// 実体は過去 PR の資産、`pr-280/x.gif -> ../.git/config` は checkout が置いた認証情報を指す）。
// 読み書きするパスは lstat で実体の種別を確かめ、realpath でも封じ込めを検査する。

function isWithin(parentReal: string, targetReal: string): boolean {
  return targetReal === parentReal || targetReal.startsWith(`${parentReal}${path.sep}`);
}

/** 実在するディレクトリの realpath を返す。リンク・非ディレクトリ・封じ込め違反は失敗させる。 */
function realDirectoryWithin(parentReal: string | null, dir: string, label: string): string | null {
  const stats = fs.lstatSync(dir, { throwIfNoEntry: false });
  if (stats === undefined) return null;
  if (!stats.isDirectory()) {
    fail(`${label} が実ディレクトリではない（シンボリックリンクの可能性）: ${dir}`);
  }
  const real = fs.realpathSync(dir);
  if (parentReal !== null && !isWithin(parentReal, real)) {
    fail(`${label} の実体が ${parentReal} の外を指している: ${real}`);
  }
  return real;
}

/** コピー元は「リンクでない通常ファイル」かつ実体が pr-<番号>/ 配下であること。 */
function assertReadableAsset(source: string, prDirReal: string): void {
  const stats = fs.lstatSync(source, { throwIfNoEntry: false });
  if (stats === undefined) {
    fail(`コピー元が見つからない: ${source}`);
  }
  if (!stats.isFile()) {
    fail(`コピー元が通常ファイルではない（シンボリックリンクの可能性）: ${source}`);
  }
  if (!isWithin(prDirReal, fs.realpathSync(source))) {
    fail(`コピー元の実体が ${prDirReal} の外を指している: ${source}`);
  }
}

/**
 * 書き込み先・削除先は features/<機能>/（または screens/）の実体配下で、既存ファイルが
 * あるならリンクでないこと。まだ存在しない親（初回の screens/）は mkdir に任せる。
 */
function assertWritableTarget(target: string, featuresDirReal: string): void {
  const parentReal = realDirectoryWithin(featuresDirReal, path.dirname(target), "書き込み先の親");
  if (parentReal === null) return;

  const stats = fs.lstatSync(target, { throwIfNoEntry: false });
  if (stats !== undefined && !stats.isFile()) {
    fail(`書き込み先が通常ファイルではない（シンボリックリンクの可能性）: ${target}`);
  }
}

/**
 * features/ 配下の meta.json を読む。ディレクトリ名と meta.feature の一致まで含めて
 * ここで検査する（顧客向け資料の生成 scripts/build-showcase.ts も同じ入口を使う。
 * カタログの読み取り規則を2箇所に持たないため export している）。
 * 引数は realpath 済みのディレクトリで、null は features/ が無い状態を表す。
 */
export function readExistingMetas(featuresDirReal: string | null): FeatureMeta[] {
  if (featuresDirReal === null) return [];

  const metas: FeatureMeta[] = [];
  for (const dirent of fs.readdirSync(featuresDirReal, { withFileTypes: true })) {
    if (dirent.isSymbolicLink()) {
      fail(`features/ の直下にシンボリックリンクがある: ${dirent.name}`);
    }
    if (!dirent.isDirectory()) continue;

    const metaPath = path.join(featuresDirReal, dirent.name, META_FILE_NAME);
    const stats = fs.lstatSync(metaPath, { throwIfNoEntry: false });
    if (stats === undefined) continue;
    if (!stats.isFile()) {
      fail(`${metaPath} が通常ファイルではない`);
    }

    const meta = parseFeatureMeta(
      JSON.parse(fs.readFileSync(metaPath, "utf8")),
      `${dirent.name}/${META_FILE_NAME}`,
    );
    if (meta.feature !== dirent.name) {
      fail(`${metaPath} の feature がディレクトリ名と一致しない: ${meta.feature}`);
    }
    metas.push(meta);
  }
  return metas;
}

function applyPlan(
  plan: CatalogPlan,
  context: { prDirReal: string; featuresDirReal: string },
): void {
  // 検査を全部済ませてから書き始める（途中まで書いて中断した状態を作らない）。
  for (const copy of plan.copies) {
    assertReadableAsset(copy.from, context.prDirReal);
  }
  for (const target of [
    ...plan.copies.map((copy) => copy.to),
    ...plan.deletions,
    ...plan.metaWrites.map((write) => write.path),
    ...(plan.readme ? [plan.readme.path] : []),
  ]) {
    assertWritableTarget(target, context.featuresDirReal);
  }

  for (const copy of plan.copies) {
    fs.mkdirSync(path.dirname(copy.to), { recursive: true });
    fs.copyFileSync(copy.from, copy.to);
  }
  // 削除はコピーの後（消す旧ファイルと今回のコピー先は画面キーが同じで拡張子だけが違うため、
  // 名前が衝突することはない）。
  for (const target of plan.deletions) {
    fs.rmSync(target, { force: true });
  }
  for (const write of plan.metaWrites) {
    const { feature, video, screens } = write.meta;
    // キー順を固定して JSON の差分をファイル内容の変化だけに絞る。
    // 空の screens は書かない（動画だけの既存 meta.json に無意味な差分を出さない）。
    const serialized = JSON.stringify(
      {
        feature,
        ...(video === null
          ? {}
          : {
              title: video.title,
              roles: video.roles,
              gif: video.gif,
              mp4: video.mp4,
              prNumber: video.prNumber,
            }),
        ...(screens.length === 0 ? {} : { screens }),
      },
      null,
      2,
    );
    fs.mkdirSync(path.dirname(write.path), { recursive: true });
    fs.writeFileSync(write.path, `${serialized}\n`);
  }
  if (plan.readme) {
    fs.mkdirSync(path.dirname(plan.readme.path), { recursive: true });
    fs.writeFileSync(plan.readme.path, plan.readme.content);
  }
}

export function buildDemoCatalog(input: { assetsDir: string; prNumber: number }): void {
  const { prNumber } = input;
  const assetsDirReal = realDirectoryWithin(null, input.assetsDir, "--assets-dir");
  if (assetsDirReal === null) {
    fail(`--assets-dir が存在しない: ${input.assetsDir}`);
  }

  const prDirReal = realDirectoryWithin(
    assetsDirReal,
    path.join(assetsDirReal, `pr-${prNumber}`),
    `pr-${prNumber}/`,
  );
  // 動画を添付しない PR が大多数なので、pr-<番号>/ や manifest の不在は通常経路として正常終了する。
  if (prDirReal === null) {
    console.log(`[demo-catalog] pr-${prNumber}/ が無いため何もしない`);
    return;
  }

  const manifestPath = path.join(prDirReal, "manifest.json");
  const manifestStats = fs.lstatSync(manifestPath, { throwIfNoEntry: false });
  if (manifestStats === undefined) {
    console.log(`[demo-catalog] pr-${prNumber}/manifest.json が無いため何もしない`);
    return;
  }
  if (!manifestStats.isFile()) {
    fail(`manifest.json が通常ファイルではない（シンボリックリンクの可能性）: ${manifestPath}`);
  }

  const manifest = parseDemoManifest(JSON.parse(fs.readFileSync(manifestPath, "utf8")));
  // Why not: prNumber の食い違いで落とさない（merge 後なので PR をやり直せない）。
  // 実体がある pr-<番号>/ を読み込み元として採用し、食い違いは警告に留める。
  // null は「録画時点で PR がまだ無い」通常経路なので警告もしない。
  if (manifest.prNumber !== null && manifest.prNumber !== prNumber) {
    console.warn(
      `[demo-catalog] manifest.prNumber (${manifest.prNumber}) が指定された PR 番号 (${prNumber}) と食い違う。読み込み元の pr-${prNumber} を採用する`,
    );
  }

  const featuresDir = path.join(assetsDirReal, FEATURES_DIR_NAME);
  const existingFeaturesDirReal = realDirectoryWithin(assetsDirReal, featuresDir, "features/");
  const plan = planCatalogUpdate({
    manifest,
    prNumber,
    existingMetas: readExistingMetas(existingFeaturesDirReal),
    // 昇格日は実行日。planCatalogUpdate を決定的に保つため、時計に触るのはここだけ。
    promotedAt: new Date().toISOString().slice(0, 10),
    assetsDir: assetsDirReal,
  });

  fs.mkdirSync(featuresDir, { recursive: true });
  applyPlan(plan, {
    prDirReal,
    featuresDirReal: existingFeaturesDirReal ?? fs.realpathSync(featuresDir),
  });

  const features = [
    ...new Set([
      ...manifest.entries.map((entry) => entry.feature),
      ...manifest.screenshots.map((screenshot) => screenshot.feature),
    ]),
  ].join(", ");
  console.log(
    `[demo-catalog] PR #${prNumber} のデモを features/ へ反映した: ${features || "なし"}`,
  );
}

function parseArgs(argv: string[]): { assetsDir: string; prNumber: number } {
  const values = new Map<string, string>();
  for (let index = 0; index < argv.length; index += 2) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (flag === undefined || value === undefined) break;
    values.set(flag, value);
  }

  const assetsDir = values.get("--assets-dir");
  const prNumber = Number(values.get("--pr"));
  if (!assetsDir || !Number.isInteger(prNumber) || prNumber <= 0) {
    fail("使い方: build-demo-catalog.ts --assets-dir <dir> --pr <番号>");
  }
  return { assetsDir: path.resolve(assetsDir), prNumber };
}

// テストから import したときは実行しない（CLI として起動されたときだけ動かす）。
// Why not: import.meta / __filename との比較にしない。このファイルは node の型ストリップ（ESM）と
// vitest の両方で読み込まれ、どちらかでしか存在しない識別子になるため。
if (path.basename(process.argv[1] ?? "").startsWith("build-demo-catalog")) {
  buildDemoCatalog(parseArgs(process.argv.slice(2)));
}
