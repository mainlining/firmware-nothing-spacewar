#!/bin/bash

firmware_output_dir=firmware
hexagonfs_firmware_output_dir=hexagonfs
hexagonfs_socinfo_source=/sys/devices/soc0
hexagonfs_socinfo_destination=socinfo

firmware_files=(
	/vendor/firmware/yupik_ipa_fws
	/vendor/firmware/ipa_fws
	/vendor/firmware/a660_zap
	/vendor/firmware_mnt/image/adsp
	/vendor/firmware_mnt/image/cdsp
	/vendor/firmware_mnt/image/modem
	/vendor/firmware_mnt/image/wpss
)

other_firmware_files=(
	/vendor/firmware_mnt/image/modem_pr
	/vendor/firmware/vpu20_1v.mbn
)

jsn_firmware_files=(
	/vendor/firmware_mnt/image/adsp
	/vendor/firmware_mnt/image/cdsp
	/vendor/firmware_mnt/image/modem
	/vendor/firmware_mnt/image/battmgr
)

hexagonfs_files_mapping_keys=(
	acdb
	dsp
	sensors/config
	sensors/registry
	sensors/sns_reg.conf
)

hexagonfs_files_mapping_values=(
	/vendor/etc/acdbdata
	/vendor/dsp
	/vendor/etc/sensors/config
	/mnt/vendor/persist/sensors/registry/registry
	/vendor/etc/sensors/sns_reg_config
)

hexagonfs_socinfo_files=(
	hw_platform
	platform_subtype
	platform_subtype_id
	platform_version
	revision
	soc_id
)

copy_and_pull() {
	local source_path="$1"
	local dest_dir="$2"

	local filename
	filename="$(basename "$source_path")"

	adb shell su -c "mkdir -p /sdcard/tmp"
	adb shell su -c "cp -r '$source_path' /sdcard/tmp/$filename"
	adb pull "/sdcard/tmp/$filename" "$dest_dir"
	adb shell su -c "rm -rf /sdcard/tmp/$filename"
}

extract_mdt_firmware() {
	local base_name="$1"
	local output_dir="$2"

	local b_files
	b_files="$(adb shell su -c "ls '$base_name.b*' 2>/dev/null" | tr '\r' ' ')"

	for f in $b_files; do
		copy_and_pull "$f" "$output_dir"
	done

	adb shell su -c "ls '$base_name.mdt' 2>/dev/null" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		copy_and_pull "$base_name.mdt" "$output_dir"
	fi
}

extract_jsn_firmware() {
	local base_name="$1"
	local output_dir="$2"

	local jsn_files
	jsn_files="$(adb shell su -c "ls '${base_name}'*.jsn 2>/dev/null" | tr '\r' ' ')"

	for f in $jsn_files; do
		copy_and_pull "$f" "$output_dir"
	done
}

mkdir -p "$firmware_output_dir"
mkdir -p "$hexagonfs_firmware_output_dir"
mkdir -p "$hexagonfs_firmware_output_dir/sensors"
mkdir -p "$hexagonfs_firmware_output_dir/$hexagonfs_socinfo_destination"

for i in "${firmware_files[@]}"; do
	extract_mdt_firmware "$i" "$firmware_output_dir"
done

for i in "${other_firmware_files[@]}"; do
	copy_and_pull "$i" "$firmware_output_dir"
done

for i in "${jsn_firmware_files[@]}"; do
	extract_jsn_firmware "$i" "$firmware_output_dir"
done

for i in "${!hexagonfs_files_mapping_keys[@]}"; do
	key="${hexagonfs_files_mapping_keys[$i]}"
	val="${hexagonfs_files_mapping_values[$i]}"

	mkdir -p "$hexagonfs_firmware_output_dir/$key"

	copy_and_pull "$val" "$hexagonfs_firmware_output_dir/$key"
done

for i in "${hexagonfs_socinfo_files[@]}"; do
	copy_and_pull \
		"$hexagonfs_socinfo_source/$i" \
		"$hexagonfs_firmware_output_dir/$hexagonfs_socinfo_destination"
done
