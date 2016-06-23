#!/bin/bash

cat <<EOF
Welcome to the desktopcontainers/debian-desktop container
EOF

# only on container boot
INITIALIZED="/.initialized"
if [ ! -f "$INITIALIZED" ]; then
	touch "$INITIALIZED"
	
	if [ -z ${DISABLE_SSHD+x} ]; then
		echo ">> preparations for SSHD"
		mkdir /var/run/sshd
		sed -i 's,^ *PermitEmptyPasswords .*,PermitEmptyPasswords yes,' /etc/ssh/sshd_config
		sed -i '1iauth sufficient pam_permit.so' /etc/pam.d/sshd
	fi
	
	if [ ! -z ${VNC_PASSWORD+x} ]; then
		VNC_PASSWORD="debian"
	fi

	if [ -z ${DISABLE_VNC+x} ]; then
		echo ">> setting new VNC password"
		su -l -s /bin/sh -c "touch ~/.Xresources; mkdir ~/.vnc; echo \"$VNC_PASSWORD\" | vncpasswd -f > ~/.vnc/passwd" app
		su -l -s /bin/sh -c "mkdir ~/Desktop; ln -s /bin/ssh-app.sh ~/Desktop/Start\ App.sh" app
	fi
	
	unset VNC_PASSWORD

	if [ -z ${DISABLE_VNC+x} ] && [ -z ${DISABLE_WEBSOCKIFY+x} ] && [ ! -z ${ENABLE_SSL+x} ]; then
		echo ">> enabling SSL"
		
		if [ ! -z ${SSL_ONLY+x} ]; then
			echo ">> enable SSL only"
			SSL_ONLY="--ssl-only"
		fi

		if [ -z ${SSL_SUBJECT+x} ]; then
			SSL_SUBJECT="/C=XX/ST=XXXX/L=XXXX/O=XXXX/CN=localhost";
		fi
		
		if [ -z ${SSL_DAYS+x} ]; then
			SSL_DAYS="3650";
		fi
	
		if [ -z ${SSL_SIZE+x} ]; then
			SSL_SIZE="4086";
		fi
	
		if [ -z ${SSL_CERT+x} ]; then
			SSL_CERT="/opt/websockify/self.pem";
		fi
		
		if [ ! -f "$SSL_CERT" ]; then
			echo ">> generating self signed cert"
			echo ">> >>    DAYS: $SSL_DAYS"
			echo ">> >>    SIZE: $SSL_SIZE"
			echo ">> >> SUBJECT: $SSL_SUBJECT"
			echo ">> >>    CERT: $SSL_CERT"
			openssl req -x509 \
				-newkey "rsa:$SSL_SIZE" \
				-days "$SSL_DAYS" \
				-subj "$SSL_SUBJECT" \
				-out "$SSL_CERT" \
				-keyout "$SSL_CERT" \
				-nodes \
				-sha256
		fi
	fi
fi

if [ -z ${DISABLE_VNC+x} ]; then
	if [ -z ${VNC_SCREEN_RESOLUTION+x} ]; then
		VNC_SCREEN_RESOLUTION="1280x800"
	fi

	echo ">> staring vncserver ($VNC_SCREEN_RESOLUTION) :1 on port 5901"
	su -l -s /bin/sh -c "export USER=app; vncserver :1 -geometry \"$VNC_SCREEN_RESOLUTION\" -depth 24" app

	sleep 2

	if [ -z ${DISABLE_WEBSOCKIFY+x} ]; then
		echo ">> starting websockify on port 80"
		/opt/websockify/run -D 80 $SSL_ONLY ${SSL_CERT:+--cert ${SSL_CERT}} localhost:5901
	fi
fi

if [ -z ${DISABLE_SSHD+x} ]; then
	echo ">> starting sshd on port 22"
	/usr/sbin/sshd
fi

# exec CMD
echo ">> exec docker CMD"
echo "$@"
exec "$@"