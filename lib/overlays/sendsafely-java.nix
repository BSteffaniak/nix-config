# Overlay for the SendSafely Java CLI
# Dependency hash managed by: ./scripts/source-build.sh update sendsafely-java
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    input = inputs.sendsafely-java-src or null;
    source =
      if mkGitInput != null && input != null then mkGitInput "sendsafely-java-src" input else null;
    hashFile = ../source-builds/hashes/sendsafely-java.json;
  in
  if source == null then
    [ ]
  else if !builtins.pathExists hashFile then
    builtins.trace
      "WARNING: sendsafely-java hash file not found. Run: ./scripts/source-build.sh update sendsafely-java"
      [ ]
  else
    let
      hashData = builtins.fromJSON (builtins.readFile hashFile);
    in
    [
      (
        final: prev:
        let
          _ =
            if hashData.rev != source.rev then
              throw ''
                sendsafely-java: hash file is stale.
                  flake.lock rev: ${source.rev}
                  hash file rev:  ${hashData.rev}
                Run: ./scripts/source-build.sh update sendsafely-java
              ''
            else
              null;
        in
        {
          sendsafely-java = final.callPackage (
            {
              useMacOSKeychainTrustStore ? false,
            }:
            final.maven.buildMavenPackage {
              pname = "sendsafely-java";
              version = "unstable-${builtins.substring 0 7 source.rev}";
              src = source.src;
              mvnHash = hashData.mvnHash;
              nativeBuildInputs = [ final.makeWrapper ];

              installPhase = ''
                runHook preInstall

                mkdir -p $out/bin $out/share/sendsafely-java
                install -Dm644 \
                  target/sendsafely-java-1.0-SNAPSHOT-jar-with-dependencies.jar \
                  $out/share/sendsafely-java/sendsafely-java.jar
                makeWrapper ${final.jre}/bin/java $out/bin/ss \
                  ${final.lib.optionalString useMacOSKeychainTrustStore ''--add-flags "-Djavax.net.ssl.trustStoreType=KeychainStore" --add-flags "-Djavax.net.ssl.trustStore=NONE"''} \
                  --add-flags "-jar $out/share/sendsafely-java/sendsafely-java.jar"

                runHook postInstall
              '';

              meta = with final.lib; {
                description = "Interactive command-line client for SendSafely";
                homepage = "https://github.com/BSteffaniak/sendsafely-java";
                license = licenses.isc;
                mainProgram = "ss";
                platforms = platforms.unix;
              };
            }
          ) { };
        }
      )
    ]
