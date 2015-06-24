/* -*- tab-width: 8 -*- */

#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
        int pid, found, j;
        int pipes[2][2];
        char *argv2[argc];

        // Make some pipes
        pipe(pipes[0]);
        pipe(pipes[1]);

        found = 0;
        for (j = 1; j < argc; j++) {
                if (found) {
                        argv2[found++] = argv[j];
                } else if (argv[j][0] == '=' && !argv[j][1]) {
                        argv[j] = 0;
                        found = 1;
                }
        }
        argv2[found] = 0;

        if (!found) {
                fprintf(stderr, "USAGE: dpipe cmd [args ...] = cmd [args ...]\n");
                exit(1);
        }

        // Fork
        pid = fork();

        // If we're parent process, hook pipes up to each other
        if (!pid) {
                close(pipes[0][0]);
                close(pipes[1][1]);
                if (dup2(pipes[0][1], STDOUT_FILENO) == -1) perror("First dup2 in parent");
                if (dup2(pipes[1][0], STDIN_FILENO) == -1) perror("Second dup2 in parent");
                execvp(argv[1], argv+1);
        } else {
                close(pipes[0][1]);
                close(pipes[1][0]);
                if (dup2(pipes[1][1], STDOUT_FILENO) == -1) perror("First dup2 in child");
                if (dup2(pipes[0][0], STDIN_FILENO) == -1) perror("Second dup2 in child");
                execvp(argv2[1], argv2+1);
        }
}
