SWARM_CERTBOT_PLUGIN_DOMAIN="${SWARM_CERTBOT_PLUGIN_DOMAIN:-"example.com"}"
SWARM_CERTBOT_PLUGIN_EMAIL="${SWARM_CERTBOT_PLUGIN_EMAIL:-"admin@example.com"}"
SWARM_CERTBOT_PLUGIN_CERTS_VOLUME="${SWARM_CERTBOT_PLUGIN_CERTS_VOLUME:-""}"
SWARM_CERTBOT_PLUGIN_WELLKNOWN_VOLUME="${SWARM_CERTBOT_PLUGIN_WELLKNOWN_VOLUME:-""}"

cmd__manage__certs__update() {
	certbot_update ${*}
}

cmd__manage__certs__webroot() {
	certbot_webroot ${*}
}

cmd__manage__certs__test__update() {
	certbot_update ${*} --dry-run
}

cmd__manage__certs__test__webroot() {
	certbot_webroot ${*} --dry-run
}

certbot_update() {
	if [ "${1}" = "batch" ]; then
		shift
	else
		certbot_yesno
	fi
	swarm_down include_system
	local domain="${SWARM_CERTBOT_PLUGIN_DOMAIN}"
	local email="${SWARM_CERTBOT_PLUGIN_EMAIL}"
	local certs_volume="${SWARM_CERTBOT_PLUGIN_CERTS_VOLUME}"
	docker run \
		--rm \
		-v ${certs_volume}:/etc/letsencrypt \
		-p "80:80" \
		deliverous/certbot certonly \
		--standalone \
		--renew-by-default \
		--non-interactive \
		--agree-tos \
		--preferred-challenges http \
		--email "${email}" \
		-d "${domain}" \
		${*}
	certbot_note
}

certbot_webroot() {
	if [ "${1}" = "batch" ]; then
		shift
	else
		certbot_yesno
	fi
	swarm_down include_system
	local domain="${SWARM_CERTBOT_PLUGIN_DOMAIN}"
	local email="${SWARM_CERTBOT_PLUGIN_EMAIL}"
	local certs_volume="${SWARM_CERTBOT_PLUGIN_CERTS_VOLUME}"
	local wellknown_volume="${SWARM_CERTBOT_PLUGIN_WELLKNOWN_VOLUME}"
	docker run \
		--rm \
		-v ${certs_volume}:/etc/letsencrypt \
		-v ${wellknown_volume}:/webroot/.well-known \
		deliverous/certbot certonly \
		--webroot \
		-w "/webroot" \
		--renew-by-default \
		--non-interactive \
		--agree-tos \
		--preferred-challenges http \
		--email "${email}" \
		-d "${domain}" \
		${*}
	certbot_note
}

certbot_yesno() {
	yesno "are you sure to update certs? [y/N] "
}

certbot_note() {
	echo ""
	echo "NOTE:"
	echo "  all composes on swarm were stopped currently."
	echo "  'swarm up' to restart services."
	echo ""
}
