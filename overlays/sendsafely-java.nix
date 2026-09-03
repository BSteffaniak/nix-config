# SendSafely Java CLI built from source with Maven.
# Hash managed by: ./scripts/source-build.sh update sendsafely-java
{ inputs }:
final: prev:
let
  source = import ../lib/locked-source.nix { inherit (prev) lib; } {
    inherit inputs;
    inputName = "sendsafely-java-src";
    hashFile = ../pkgs/source-builds/hashes/sendsafely-java.json;
    updateCommand = "./scripts/source-build.sh update sendsafely-java";
  };
in
if source == null then
  { }
else
  {
    sendsafely-java = final.callPackage (
      {
        useMacOSKeychainTrustStore ? false,
      }:
      final.maven.buildMavenPackage {
        pname = "sendsafely-java";
        version = "unstable-${source.shortRev}";
        inherit (source) src;
        mvnHash = source.hashes.mvnHash;
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
