{ stdenv, lib, fetchFromGitHub, python310Packages, pkgs, }:
let
  idf-component-manager = python310Packages.buildPythonPackage rec {
    pname = "idf_component_manager";
    version = "1.3.2";
    src = python310Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-RPLkaAW3yxx+UirW0qZ2rCg2F8fAF1NyEB+srg+AYbs=";
    };
    doCheck = false;
    configurePhase = ''
      export HOME=$TMP
    '';
    propagatedBuildInputs = with python310Packages; [
      packaging
      lockfile
      cachecontrol
      colorama
      click
      future
      pyyaml
      requests
      requests-file
      requests-toolbelt
      schema
      six
      tqdm
      contextlib2
    ];
  };
  esptool = python310Packages.buildPythonPackage rec {
    pname = "esptool";
    version = "4.6.2";
    src = python310Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-VJ75Pu9C7n6UYs5aU8Ft96DHHZGz934Z7BV0mATN8wA=";
    };
    doCheck = false;
    propagatedBuildInputs = with python310Packages; [
      bitstring
      cryptography
      ecdsa
      pyserial
      reedsolo
      pyaml
    ];
  };
  esp-coredump = python310Packages.buildPythonPackage rec {
    pname = "esp-coredump";
    version = "1.6.0";
    src = python310Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-YT1np8HtxhlfNB5UHoi1Q/W9b7s5+RonIJjc0AZys80=";
    };
    doCheck = false;
    propagatedBuildInputs = with python310Packages; [
      esptool
      pygdbmi
      construct
      pyyaml
    ];
  };
  esp-idf-kconfig = python310Packages.buildPythonPackage rec {
    pname = "esp-idf-kconfig";
    version = "1.2.0";
    src = python310Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-HD+QlAcHQgwlkKMn0LA24CoNux0IxpORKLYBfYb39JI=";
    };
    doCheck = false;
    propagatedBuildInputs = with python310Packages; [ kconfiglib ];
  };
  esp-idf-monitor = python310Packages.buildPythonPackage rec {
    pname = "esp-idf-monitor";
    version = "1.1.1";
    src = python310Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-c62X3ZHRShhbAFmuPc/d2keqE9T9SXYIlJTyn32LPaE=";
    };
    doCheck = false;
    propagatedBuildInputs = with python310Packages; [
      pyserial
      pyelftools
      esp-coredump
    ];
  };
  esp-idf-panic-decoder = python310Packages.buildPythonPackage rec {
    pname = "esp-idf-panic-decoder";
    version = "1.0.1";
    src = python310Packages.fetchPypi {
      inherit version;
      pname = "esp_idf_panic_decoder";
      sha256 = "sha256-fvSr7TRD6aMQQPrs2x98HHW6qwFdy8gWkrQUGddor/8=";
    };
    format = "pyproject";
    doCheck = false;
    propagatedBuildInputs = with python310Packages; [
      setuptools
      wheel
      pyelftools
    ];
  };
  esp-idf-size = python310Packages.buildPythonPackage rec {
    pname = "esp-idf-size";
    version = "0.3.1";
    src = python310Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-OzthhzKGjyqDJrmJWs4LMkHz0rAwho+3Pyc2BYFK0EU=";
    };
    doCheck = false;
    propagatedBuildInputs = with python310Packages; [ pyaml ];
  };
  freertos-gdb = python310Packages.buildPythonPackage rec {
    pname = "freertos-gdb";
    version = "1.0.2";
    src = python310Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-o0ZoTy7OLVnrhSepya+MwaILgJSojs2hfmI86D9C3cs=";
    };
    doCheck = false;
    propagatedBuildInputs = with python310Packages; [ setuptools wheel ];
  };
  toolchain = pkgs.callPackage ./toolchain.nix { };
  idf-python-env = (pkgs.python310.withPackages (p:
    with p; [
      pip
      idf-component-manager
      esptool
      esp-coredump
      esp-idf-monitor
      esp-idf-kconfig
      freertos-gdb
      p.protobuf
      grpcio-tools
      pyparsing
      esp-idf-size
      esp-idf-panic-decoder
      filelock
    ]));
in stdenv.mkDerivation rec {
  pname = "esp-idf";
  version = "5.1";
  src = fetchFromGitHub {
    owner = "espressif";
    repo = "esp-idf";
    rev = "482a8fb2d78e3b58eb21b26da8a5bedf90623213";
    fetchSubmodules = true;
    name = pname;
    sha256 = "sha256-uEf3/3NPH+E39VgQ02AbxTG7nmG5bQlhwk/WcTeAUfg=";
  };

  patches = [ ./neutralize-python-dependency-checks.patch ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  propagatedBuildInputs = with pkgs; [
    which
    toolchain
    git
    cmake
    ninja
    protobuf
    idf-python-env
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir sdk
    cp -r $src/* sdk
    chmod -R +w sdk 
    # permits the patchPhase to modify the sources
    # (for some reason cp makes them read-only, even though we are the owner of the files)
    runHook postUnpack
  '';

  preBuildPhase = ''
    export HOME=$TMP
  '';

  installPhase = ''
    runHook preInstall

    # Fake venv, idf actually checks this
    mkdir -p $out/sdk $out/.espressif/python_env/idf${version}_py3.10_env/bin
    ln -s $(readlink -e $(which python3)) $out/.espressif/python_env/idf${version}_py3.10_env/bin/python
    touch $out/.espressif/espidf.constraints.v${version}.txt
    cp -r sdk/* $out/sdk

    # no .git, inject version
    echo "v${version}" >> $out/sdk/version.txt

    # prepare wrapper, that includes all idf-related env
    makeWrapper $out/.espressif/python_env/idf${version}_py3.10_env/bin/python $out/bin/idf.py \
    --add-flags $out/sdk/tools/idf.py \
    --set IDF_TOOLS_PATH $out/.espressif \
    --set IDF_PYTHON_ENV_PATH $out/.espressif/python_env/idf${version}_py3.10_env \
    --set IDF_PATH $out/sdk/ \
    --set PYTHONPATH ${idf-python-env}/${idf-python-env.sitePackages}:$PYTHONPATH \
    --prefix PATH : "${lib.makeBinPath propagatedBuildInputs}"

    # wrapper around esptool.py
    makeWrapper $out/.espressif/python_env/idf${version}_py3.10_env/bin/python $out/bin/esptool.py \
    --add-flags $out/sdk/components/esptool_py/esptool/esptool.py \
    --set IDF_TOOLS_PATH $out/.espressif \
    --set IDF_PYTHON_ENV_PATH $out/.espressif/python_env/idf${version}_py3.10_env \
    --set IDF_PATH $out/sdk/ \
    --prefix PATH : "${lib.makeBinPath propagatedBuildInputs}"
    runHook postInstall
  '';

  shellHook = ''
    export PYTHONPATH=${idf-python-env}/${idf-python-env.sitePackages}:$PYTHONPATH
    export PATH="${lib.makeBinPath propagatedBuildInputs}":$PATH
  '';

  phases = ["unpackPhase" "patchPhase" "preBuildPhase" "installPhase" ];

  dontConfigure = true;

  meta = with lib; {
    description = "SDK for Espressif's chips";
    homepage = "https://github.com/espressif/esp-idf";
    license = licenses.gpl3;
  };
}

