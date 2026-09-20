#!/usr/bin/env bash

echo -e "[TUTORIAL]\n\n \
1. Adicione o PDF original em Desktop/metadata_cloning/PDFs/Originais.\n \
2. Adicione o editado em Desktop/metadata_cloning/PDFs/Editados.\n \
3. Renomeie o editado para exatamente o mesmo nome do documento real.\n"

echo -e "[AVISO] Este script não funcionará corretamente se o nome do pdf original e do editado não forem idêntios.\n"

echo "Iniciar script? [s/n]"

read -r argX

if [[ ! "$argX" =~ ^[sS]$ ]]; then

	echo "[AVISO] Script encerrado pelo usuário."
	exit 1

else

	echo "[AVISO] Executando o script"

	if ! command -v exiftool &>/dev/null; then
	    if command -v apt-get &>/dev/null; then
		apt-get update && apt-get install -y libimage-exiftool-perl
	    elif command -v pacman &>/dev/null; then
		pacman -Sy --noconfirm perl-image-exiftool
	    elif command -v dnf &>/dev/null; then
		dnf install -y perl-Image-ExifTool
	    elif command -v zypper &>/dev/null; then
		zypper --non-interactive install perl-Image-ExifTool
	    elif command -v apk &>/dev/null; then
		apk add exiftool
	    else
		echo "[ERRO] Package manager não suportado." >&2
		exit 1
	    fi
	fi

	readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

	mkdir -p "$ROOT_DIR/PDFs"
	mkdir -p "$ROOT_DIR/PDFs/Originais"
	mkdir -p "$ROOT_DIR/PDFs/Editados"

	mapfile -d "" files < <(
		find "$ROOT_DIR/PDFs/Originais/" \
		-type f \
		-iname "*.pdf" \
		-print0
	)

	for i in "${files[@]}"; do
		base_name="$(basename "$i")"
		output="$ROOT_DIR/PDFs/Editados/$base_name"

		if [ ! -f "$output" ]; then
			
			echo "[ERRO] $output não existe."
			continue
		fi

                xmp_tmp="$(mktemp)"
                exiftool -b -xmp "$i" > "$xmp_tmp" 2>/dev/null
                xmp_args=()
                [ -s "$xmp_tmp" ] && xmp_args=("-xmp<=$xmp_tmp")

                if exiftool -all:all= "${xmp_args[@]}" \
                -TagsFromFile "$i" -all:all --xmp:all -PDF:Trapped \
                -P -overwrite_original "$output" &>/dev/null; then

			echo "[SUCESSO] $output com metadados idênticos ao original."

		else
			echo "[ERRO] $output não recebeu metadados do original."

		fi


		rm -f "$xmp_tmp"
		touch -r "$i" "$output"

                diff_out="$(diff \
                        <(exiftool -a -G1 -s --File:all --ExifTool:all --PDF:MediaBox "$i" | sort) \
                        <(exiftool -a -G1 -s --File:all --ExifTool:all --PDF:MediaBox "$output" | sort))"
                if [ -z "$diff_out" ]; then
                        echo "[DIFF] $base_name: metadados idênticos."
                else
                        echo "[DIFF] $base_name: diferenças (< original | > editado):"
                        echo "$diff_out"
                fi
	done

fi
