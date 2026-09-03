{
  lib,
  stdenv,
  SDL2,
  fetchurl,
  fetchFromGitHub,
  fetchpatch,
  gzip,
  libvorbis,
  libmad,
  flac,
  libopus,
  opusfile,
  libogg,
  libGL,
  curl,
  libxmp,
  mpg123,
  vulkan-headers,
  vulkan-loader,
  copyDesktopItems,
  makeDesktopItem,
  pkg-config,
  glib,
  jansson,
  stdenvNoCC,
  openssl,
  zlib,
  libuv,
  cmake,
}: let
  # need to pin to 4.4.1 as 4.4.5 weirdly truncates messages to 1024 characters
  libwebsockets = stdenv.mkDerivation (finalAttrs: {
    pname = "libwebsockets";
    version = "4.4.1";

    src = fetchFromGitHub {
      owner = "warmcat";
      repo = "libwebsockets";
      rev = "v${finalAttrs.version}";
      hash = "sha256-Xvcnfvm9UCNXm3G3tVe7jExE3fwpzYuz8wllvINymeI=";
    };

    patches = [
      (fetchpatch {
        name = "CVE-2025-11677.patch";
        url = "https://libwebsockets.org/git/libwebsockets/patch?id=2f082ec31261f556969160143ba94875d783971a";
        hash = "sha256-FeiZAbr1kpt+YNjhi2gfG2A6nXKiSssMFRmlALaneu4=";
      })
      (fetchpatch {
        name = "CVE-2025-11678.patch";
        url = "https://libwebsockets.org/git/libwebsockets/patch?id=2bb9598562b37c942ba5b04bcde3f7fdf66a9d3a";
        hash = "sha256-1uQUkoMbK+3E/QYMIBLlBZypwHBIrWBtm+KIW07WRj8=";
      })
    ];

    outputs = [
      "out"
      "dev"
    ];

    buildInputs = [
      openssl
      zlib
      libuv
    ];

    nativeBuildInputs = [
      cmake
    ];

    cmakeFlags = [
      "-DLWS_WITH_PLUGINS=ON"
      "-DLWS_WITH_IPV6=ON"
      "-DLWS_WITH_SOCKS5=ON"
      "-DDISABLE_WERROR=ON"
      "-DLWS_BUILD_HASH=no_hash"
      "-DLWS_WITHOUT_TESTAPPS=ON"
      "-DLWS_WITH_STATIC=OFF"
      "-DLWS_LINK_TESTAPPS_DYNAMIC=ON"

      "-DLWS_WITHOUT_EXTENSIONS=OFF"
    ];

    postInstall = ''
      # Fix path that will be incorrect on move to "dev" output.
      substituteInPlace "$out/lib/cmake/libwebsockets/LibwebsocketsTargets-release.cmake" \
        --replace "\''${_IMPORT_PREFIX}" "$out"

      # The package builds a few test programs that are not usually necessary.
      # Move those to the dev output.
      moveToOutput "bin/libwebsockets-test-*" "$dev"
      moveToOutput "share/libwebsockets-test-*" "$dev"
    '';

    # $out/share/libwebsockets-test-server/plugins/libprotocol_*.so refers to crtbeginS.o
    disallowedReferences = [ stdenv.cc.cc ];

    meta = {
      description = "Light, portable C library for websockets";
      longDescription = ''
        Libwebsockets is a lightweight pure C library built to
        use minimal CPU and memory resources, and provide fast
        throughput in both directions.
      '';
      homepage = "https://libwebsockets.org/";
      # Relicensed from LGPLv2.1+ to MIT with 4.0. Licensing situation
      # is tricky, see https://github.com/warmcat/libwebsockets/blob/main/LICENSE
      license = with lib.licenses; [
        mit
        publicDomain
        bsd3
        asl20
      ];
      maintainers = with lib.maintainers; [ mindavi ];
      platforms = lib.platforms.all;
    };
  });
  rapidhash = stdenvNoCC.mkDerivation rec {
    pname = "rapidhash";
    version = "1.0";

    src = fetchurl {
      url = "https://github.com/Nicoshev/rapidhash/archive/refs/tags/rapidhash_v${version}.tar.gz";
      hash = "sha256-0pXmbuxnRcwODIxl+4te3wirOvg7ClA8VMZwUUS1OEg=";
    };

    installPhase = ''
      mkdir "$out"
      cp rapidhash.h "$out"
      cp secret.h "$out"
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ironwail-ap";
  version = "1.1.9";

  src = ./../Quake;

  nativeBuildInputs = [
    copyDesktopItems
    pkg-config
    vulkan-headers
    gzip
    libGL
    libvorbis
    libmad
    flac
    curl
    libopus
    opusfile
    libogg
    libxmp
    mpg123
    vulkan-loader
    SDL2
    glib
    jansson
    libwebsockets
  ];

  buildFlags = [
    "DO_USERDIRS=1"
    # Makefile defaults, set here to enforce consistency on Darwin build
    "USE_CODEC_WAVE=1"
    "USE_CODEC_MP3=1"
    "USE_CODEC_VORBIS=1"
    "USE_CODEC_FLAC=1"
    "USE_CODEC_OPUS=1"
    "USE_CODEC_MIKMOD=0"
    "USE_CODEC_UMX=0"
    "USE_CODEC_XMP=1"
    "MP3LIB=mad"
    "VORBISLIB=vorbis"
    "SDL_CONFIG=sdl2-config"
    "USE_SDL2=1"
  ];

  postPatch = ''
    substituteInPlace quakedef.h \
      --replace-fail '#define ENGINE_USERDIR_UNIX		".ironwail"' '#define ENGINE_USERDIR_UNIX		".ironwail-ap"' \
      --replace-fail '#define IRONWAIL_VER_SUFFIX		""' '#define IRONWAIL_VER_SUFFIX		"-ap${finalAttrs.version}"'

    substituteInPlace Makefile \
      --replace-fail 'cp ironwail.pak /usr/local/games/quake' "cp ironwail.pak $out/share/quake/ironwail.pak" \
      --replace-fail '/usr/local/games/quake' "$out/bin/ironwail-ap" \
      --replace-fail 'COMMON_LIBS= -lGL -ldl -lm' 'COMMON_LIBS= -lGL -ldl -lm -lglib-2.0 -lwebsockets -ljansson
CFLAGS+= -I${rapidhash}'

    substituteInPlace ap_impl.c \
      --replace-fail '/.ironwail' '/.ironwail-ap'
  '';

  preBuild = ''
    NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE $(pkg-config --cflags glib-2.0 libwebsockets jansson) -Wno-incompatible-pointer-types -Wno-error=format-security"
    NIX_LDFLAGS="$NIX_LDFLAGS -lFLAC -lopusfile -lxmp"
  '';

  preInstall = ''
    mkdir -p "$out/bin"
    mkdir -p "$out/share/quake"
  '';

  enableParallelBuilding = true;

  desktopItems = [
    (makeDesktopItem {
      name = "ironwail-ap";
      exec = "ironwail-ap";
      desktopName = "Ironwail AP";
      categories = [ "Game" ];
    })
  ];

  meta = {
    description = "Fork of the QuakeSpasm engine for iD software's Quake (with Archipelago support)";
    homepage = "https://github.com/andrei-drexler/ironwail";
    longDescription = ''
      Ironwail is a fork of QuakeSpasm with focus on high performance instead of
      compatibility.
      It features the ability to play the 2021 re-release content with no setup
      required, a mods menu for quick access to installation of mods, and ease of
      switching to installed mods.
      It also include various visual features as well as improved limits for playing
      larger levels with less performance impacts.
    '';

    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "ironwail-ap";
  };
})
