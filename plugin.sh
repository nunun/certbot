SWARM_CERTBOT_PLUGIN_DOMAIN="${SWARM_CERTBOT_PLUGIN_DOMAIN:-"example.com"}"
SWARM_CERTBOT_PLUGIN_EMAIL="${SWARM_CERTBOT_PLUGIN_EMAIL:-"admin@example.com"}"
SWARM_CERTBOT_PLUGIN_CERT_PEM="${SWARM_CERTBOT_PLUGIN_CERT_PEM:-"swarm_cert_pem"}"
SWARM_CERTBOT_PLUGIN_CHAIN_PEM="${SWARM_CERTBOT_PLUGIN_CHAIN_PEM:-"swarm_chain_pem"}"
SWARM_CERTBOT_PLUGIN_FULLCHAIN_PEM="${SWARM_CERTBOT_PLUGIN_FULLCHAIN_PEM:-"swarm_fullchain_pem"}"
SWARM_CERTBOT_PLUGIN_PRIVKEY_PEM="${SWARM_CERTBOT_PLUGIN_PRIVKEY_PEM:-"swarm_privkey_pem"}"
SWARM_CERTBOT_PLUGIN_CACHE_VOLUME_NAME="certbot_cache_data"
SWARM_CERTBOT_PLUGIN_TEST_VOLUME_NAME="certbot_test_data"

on_install() {
        log_debug "swarm-certbot-plugin: on_install (${*})"
        install_certbot_secrets
}

on_reinstall() {
        log_debug "swarm-certbot-plugin: on_reinstall (${*})"
        install_certbot_secrets
}

###############################################################################
###############################################################################
###############################################################################

cmd__manage__certbot__certs__update__by_request() {
	update_certbot_secrets request ${*}
}

cmd__manage__certbot__certs__update__by_cached() {
	update_certbot_secrets update ${*}
}

cmd__manage__certbot__certs__update__test() {
	update_certbot_secrets test ${*}
}

cmd__manage__certbot__certs__shell__cache_volume() {
	local volume_name="${SWARM_CERTBOT_PLUGIN_CACHE_VOLUME_NAME}"
	docker run --rm -it -v ${volume_name}:/etc/letsencrypt --workdir /etc/letsencrypt alpine:3.6 sh
}

cmd__manage__certbot__certs__shell__test_volume() {
	local volume_name="${SWARM_CERTBOT_PLUGIN_TEST_VOLUME_NAME}"
	docker run --rm -it -v ${volume_name}:/etc/letsencrypt --workdir /etc/letsencrypt alpine:3.6 sh
}

###############################################################################
###############################################################################
###############################################################################

# install docker secrets
# NOTE its dummy until 'swarm manage certs update'.
install_certbot_secrets() {
	local cert_path="/tmp/cert.pem"
	local key_path="/tmp/privkey.pem"
	local domain="${SWARM_CERTBOT_PLUGIN_DOMAIN}"
	local cert_pem="${SWARM_CERTBOT_PLUGIN_CERT_PEM}"
	local chain_pem="${SWARM_CERTBOT_PLUGIN_CHAIN_PEM}"
	local fullchain_pem="${SWARM_CERTBOT_PLUGIN_FULLCHAIN_PEM}"
	local privkey_pem="${SWARM_CERTBOT_PLUGIN_PRIVKEY_PEM}"
	if [    -z "`docker secret ls -q -f name="${cert_pem}"`" \
	     -o -z "`docker secret ls -q -f name="${chain_pem}"`" \
	     -o -z "`docker secret ls -q -f name="${fullchain_pem}"`" \
	     -o -z "`docker secret ls -q -f name="${privkey_pem}"`" ]; then
		log_info "generating certs ..."
		sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-subj "/CN=${domain} /O=${domain} /C=JP" \
			-out "${cert_path}" -keyout "${key_path}"
		certbot_secret_rm "${cert_pem}"
		certbot_secret_rm "${chain_pem}"
		certbot_secret_rm "${fullchain_pem}"
		certbot_secret_rm "${privkey_pem}"
		certbot_secret_create_from_file "${cert_pem}"      "${cert_path}"
		certbot_secret_create_from_file "${chain_pem}"     "${cert_path}"
		certbot_secret_create_from_file "${fullchain_pem}" "${cert_path}"
		certbot_secret_create_from_file "${privkey_pem}"   "${key_path}"
	fi
}

# create docker secrets
update_certbot_secrets() {
	local mode="${1:-"test"}"
	local domain="${SWARM_CERTBOT_PLUGIN_DOMAIN}"
	local email="${SWARM_CERTBOT_PLUGIN_EMAIL}"
	local cert_pem="${SWARM_CERTBOT_PLUGIN_CERT_PEM}"
	local chain_pem="${SWARM_CERTBOT_PLUGIN_CHAIN_PEM}"
	local fullchain_pem="${SWARM_CERTBOT_PLUGIN_FULLCHAIN_PEM}"
	local privkey_pem="${SWARM_CERTBOT_PLUGIN_PRIVKEY_PEM}"
	local cache_volume_name="${SWARM_CERTBOT_PLUGIN_CACHE_VOLUME_NAME}"
	local test_volume_name="${SWARM_CERTBOT_PLUGIN_TEST_VOLUME_NAME}"
	shift 1

	# mode
	local request=""
	local update=""
	local certbot_args=""
	local volume_name="${test_volume_name}"
	case "${mode}" in
	request) request="1"; update="1"; certbot_args=""; volume_name="${cache_volume_name}";;
	update)  request="";  update="1"; certbot_args=""; volume_name="${cache_volume_name}";;
	test)    request="1"; update="";  certbot_args="--dry-run"; volume_name="${test_volume_name}";;
	*) abort "update_certbot_secrets: unknown mode '${mode}'."
	esac

	# requst
	if [ -n "${request}" ]; then
		swarm_down force_all
		log_info "requesting certs ..."
		docker run \
			--rm \
			-v ${volume_name}:/etc/letsencrypt \
			-p "80:80" \
			deliverous/certbot certonly \
			--standalone \
			--renew-by-default \
			--non-interactive \
			--agree-tos \
			--preferred-challenges http \
			--email "${email}" \
			-d "${domain}" \
			${certbot_args} \
			${*}
	fi

	# update
	if [ -n "${update}" ]; then
		certbot_secret_rm "${cert_pem}"
		certbot_secret_rm "${chain_pem}"
		certbot_secret_rm "${fullchain_pem}"
		certbot_secret_rm "${privkey_pem}"
		certbot_secret_create_from_volume "${cert_pem}"      "${volume_name}" "live/${domain}/cert.pem"
		certbot_secret_create_from_volume "${chain_pem}"     "${volume_name}" "live/${domain}/chain.pem"
		certbot_secret_create_from_volume "${fullchain_pem}" "${volume_name}" "live/${domain}/fullchain.pem"
		certbot_secret_create_from_volume "${privkey_pem}"   "${volume_name}" "live/${domain}/privkey.pem"
	fi
}

###############################################################################
###############################################################################
###############################################################################

certbot_secret_create_from_file() {
	local secret_name="${1}"
	local file_path="${2}"
	log_info "create docker secret '${secret_name}' from ${file_path} ..."
	cat "${file_path}" | docker secret create "${secret_name}" -
}

certbot_secret_create_from_volume() {
	local secret_name="${1}"
	local volume_name="${2}"
	local volume_path="${3}"
	log_info "create docker secret '${secret_name}' from ${volume_name}:${volume_path} ..."
	docker run \
		--rm \
		-v ${volume_name}:/volume \
		alpine:3.6 \
		cat "/volume/${volume_path}" \
		| docker secret create "${secret_name}" -
}

certbot_secret_rm() {
	local secret_name="${1}"
	local found="`docker secret ls -q -f name="${secret_name}"`"
	if [ -n "${found}" ]; then
		log_info "remove docker secret '${secret_name}' ..."
		docker secret rm "${secret_name}"
	fi
}
