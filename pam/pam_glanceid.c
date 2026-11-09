#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <security/pam_appl.h>
#include <security/pam_modules.h>

#define GLANCEID_PATH "/Applications/GlanceID.app/Contents/MacOS/GlanceID"

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    if (access(GLANCEID_PATH, X_OK) != 0) {
        return PAM_AUTH_ERR;
    }

    pid_t pid = fork();
    if (pid < 0) {
        return PAM_AUTH_ERR;
    }

    if (pid == 0) {
        // Run GlanceID headless Face ID verification
        execl(GLANCEID_PATH, "GlanceID", "--verify", (char *)NULL);
        _exit(1);
    }

    int status = 0;
    waitpid(pid, &status, 0);

    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        return PAM_SUCCESS;
    }

    return PAM_AUTH_ERR;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}

PAM_EXTERN int pam_sm_acct_mgmt(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}
