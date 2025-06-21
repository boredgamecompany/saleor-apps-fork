[supervisord]
nodaemon=true
user=root
logfile=/dev/stdout
logfile_maxbytes=0
pidfile=/var/run/supervisord.pid

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:node]
command=node /workspace/apps/{{PROJECT}}/server.js
autostart=true
autorestart=true
user=nextjs
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
environment=NODE_ENV="{{NODE_ENV}}",PROJECT="{{PROJECT}}",VERSION="{{VERSION}}",HOSTNAME=0.0.0.0
