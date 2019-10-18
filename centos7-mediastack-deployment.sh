
#!/bin/bash 

#Update all packages
yum update -y

#Install preferred editor and utils for connecting to Windows shares
yum install nano cifs-utils  rsync -y

#Create SMB credentials file
echo "username=user
password=somepassword" >> /.smbcredentials

#Make media mount directories
mkdir /media/movies /media/tv /media/seasonal

#Add mount points
echo "//10.0.0.103/movies /media/movies cifs credentials=/.smbcredentials,uid=1000,gid=1000,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777,sec=ntlmv2i 0 0
//10.0.0.103/seasonal /media/seasonal cifs credentials=/.smbcredentials,uid=1000,gid=1000,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777,sec=ntlmv2i 0 0
//10.0.0.103/tv /media/tv  cifs credentials=/.smbcredentials,uid=1000,gid=1000,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777,sec=ntlmv2i 0 0" >> /etc/fstab

mount -a

##Install Docker

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl start docker
sudo systemctl enable docker

#Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

#Create Docker compose file

mkdir /containers

echo "version: '3.3'

services:
  transmission:
    container_name: transmission
    image: linuxserver/transmission:latest
    volumes:
      - /containers/transmission:/config 
      - /downloaders/completed:/downloads 
      - /downloaders/incomplete/torrents:/incomplete 
    restart: unless-stopped
    networks: 
      - media-bridge
    environment:
      PUID: 1000 
      PGID: 1000 
      TZ: \"America/New_York\"
    ports:
      - \"9091:9091\" 
      - \"51413:51413\" 
      - \"51413:51413/udp\"
  
  sabnzbd:
    container_name: sabnzbd
    image: linuxserver/sabnzbd:latest
    volumes:
      - /containers/sabnzbd:/config 
      - /downloaders/completed:/downloads 
      - /downloaders/incomplete/usenet:/incomplete
    restart: unless-stopped
    networks: 
      - media-bridge
    environment:
      PUID: 1000
      PGID: 1000
      TZ: \"America/New_York\"
    ports:
      - \"8080:8080\"
      - \"9090:9090\"

  sonarr:
    container_name: sonarr
    image: linuxserver/sonarr:latest
    volumes:
    - /containers/sonarr:/config 
    - /media/tv/Active:/tv 
    - /downloaders/completed/tv:/downloads/tv
    restart: unless-stopped
    depends_on:
      - transmission
      - sabnzbd
      - jackett
    networks: 
      - media-bridge
    environment:
      PUID: 1000
      PGID: 1000
      TZ: \"America/New_York\"
    ports:
      - \"8989:8989\"

  radarr:
    container_name: radarr
    image: linuxserver/radarr:latest
    volumes:
      - /containers/radarr:/config 
      - /downloaders/completed/movies:/downloads/movies 
      - /media/movies:/movies 
      - /etc/localtime:/etc/localtime:ro 
    restart: unless-stopped
    depends_on:
      - transmission
      - sabnzbd
      - jackett
    networks: 
      - media-bridge
    environment:
      PGID: 1000
      PUID: 1000
      TZ: \"America/New_York\"
    ports:
      - \"7878:7878\"
  
  plexpy:
    container_name: plexpy
    image: linuxserver/plexpy:latest
    volumes:
      - /containers/plexpy:/config 
      - /containers/plex/database/Library/Application\ Support/Plex\ Media\ Server/Logs:/logs:ro
    restart: unless-stopped
    depends_on: 
      - plex
    networks: 
      - media-bridge
    environment:
      PGID: 1000
      PUID: 1000
    ports:
        - \"8182:8181\"

  plex:
    container_name: plex
    image: plexinc/pms-docker:latest
    volumes:
      - /containers/plex/database:/config 
      - /containers/plex/transcode:/transcode 
      - /media:/data
    restart: unless-stopped
    depends_on:
      - transmission
      - sabnzbd
      - sonarr
      - radarr
    networks: 
      - media-bridge
    environment:
      TZ: \"America/New_York\"
      PLEX_CLAIM: \"<claimToken>\"
      ADVERTISE_IP: \"http://centos:32400/\"
    ports:
        - \"8181:8181\"
        - \"32400:32400\"
        - \"3005:3005\"
        - \"8324:8324\"
        - \"32469:32469\"
        - \"1900:1900\"
        - \"32410:32410\"
        - \"32412:32412\"
        - \"32413:32413\"
        - \"32414:32414\"

  portainer:
    container_name: portainer
    image: portainer/portainer:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock 
      - /containers/portainer:/data
    restart: unless-stopped
    network_mode: bridge 
    ports:
      - \"9000:9000\"  

  ombi:
    container_name: ombi
    image: linuxserver/ombi:latest
    volumes: 
      - /containers/ombi/config:/config
    restart: unless-stopped
    networks: 
      - media-bridge
    depends_on:
      - transmission
      - sabnzbd
      - sonarr
      - radarr
    environment:
      PUID: 1000 
      PGID: 1000 
      TZ: \"America/New_York\"
    ports:
      - \"3579:3579\"

  jackett:
    container_name: jackett
    image: linuxserver/jackett:latest
    volumes:
      - /containers/jackett/config:/config
      - /containers/jackett/blackhole:/downloads
    restart: unless-stopped
    networks: 
      - media-bridge
    environment:
      PUID: 1000
      PGID: 1000
      TZ: \"America/New_York\"
    ports:
      - 9117:9117

networks:
  media-bridge:" >> /containers/docker-compose.yml

#Start media stack
docker-compose -f /containers/docker-compose.yml up -d
  
#Set permissions
chomd 777 /downloaders -R
