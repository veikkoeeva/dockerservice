docker build -f "./ListenerService/Dockerfile" --force-rm -t listenerservice:dev --target final --label "com.microsoft.created-by=visual-studio" --label "com.microsoft.visual-studio.project-name=ListenerService" "C:\projektit\DockerService"