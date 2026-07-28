{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, nodejs_24
}:

stdenvNoCC.mkDerivation (finalAttrs: {
	pname = "kimi-code";
	version = "0.29.1";

	src = fetchurl {
		url = "https://registry.npmjs.org/@moonshot-ai/kimi-code/-/kimi-code-${finalAttrs.version}.tgz";
		hash = "sha256-CpGJ62GVZXgbCS5REG81XQ1SqbWdxeaQy1fIml4PAz8=";
	};

	nativeBuildInputs = [ makeWrapper ];

	# npm tarball unpacks to ./package
	sourceRoot = "package";

	installPhase = ''
		runHook preInstall

		mkdir -p $out/lib/kimi-code
		cp -r dist dist-web native package.json $out/lib/kimi-code/

		mkdir -p $out/bin
		makeWrapper ${lib.getExe nodejs_24} $out/bin/kimi \
			--add-flags "$out/lib/kimi-code/dist/main.mjs" \
			--set KIMI_CODE_NO_AUTO_UPDATE 1

		runHook postInstall
	'';

	meta = {
		description = "Kimi Code — agentic coding CLI from Moonshot AI";
		homepage = "https://github.com/MoonshotAI/kimi-code";
		license = lib.licenses.mit;
		mainProgram = "kimi";
		platforms = lib.platforms.linux;
	};
})
