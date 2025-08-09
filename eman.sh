#!/bin/bash

help() {
    cat <<EOF
    eman check-verilator            : print the version of the first found Verilator (if there are multiple version of Verilator installed)
    eman verilator-example          : compile and run the Verilator example(s)
    eman change-verilator <VERSION> : change default Verilator to different version. If not installed, install it.

    eman c-compiler-version         : print the version of default C compiler and the version of GNU Make
    eman c-compiler-example         : compile and run the C/C++ example(s)

EOF
}

c_compiler_version() {
    echo "C compiler version:"
    gcc --version | head -n1
    echo "Make version:"
    make --version | head -n1
}

c_compiler_example() {
    EX_DIR="/ubuntu-base/example/c_cpp"
    pushd "$EX_DIR" > /dev/null
    make clean && make all && make run
    popd > /dev/null
}

check_verilator() {
    if command -v verilator &> /dev/null; then
        verilator --version
    else
        echo "Verilator not found"
        return 1
    fi
}

verilator_example() {
    EX_DIR="/ubuntu-base/example/verilog"
    pushd "$EX_DIR" > /dev/null
    make clean && make run
    popd > /dev/null
}

change_verilator() {
    local version="$1"
    if [ -z "$version" ]; then
        echo "Usage: eman change-verilator <VERSION>"
        return 1
    fi
    
    local ver_path="/opt/verilator-$1/bin/verilator"
    if [ ! -x "$ver_path" ]; then
        echo "Version $1 not found"
        return 1
    fi
    alias verilator="$ver_path"
    echo "Switched to Verilator $1 (alias created)"
    verilator --version
}

case "$1" in
    help|"") help ;;
    c-compiler-version) c_compiler_version ;;
    c-compiler-example) c_compiler_example ;;
    check-verilator) check_verilator ;;
    verilator-example) verilator_example ;;
    change-verilator) change_verilator "$2" ;;
    *) echo "Unknown command: $1"; help ;;
esac
