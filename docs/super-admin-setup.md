# Super Admin setup (no credentials in source)

Previously published Super Admin passwords are **compromised**. Rotate them in
Firebase Authentication. Do not put a replacement password in git.

## Create the first Super Admin

1. Firebase Console → Authentication → Add user (email/password). Copy the UID.
2. Firestore → `admins/{UID}` document:

```
uid: <same UID>
email: <auth email>
name: Super Admin
role: superadmin
isActive: true
phone: <phone>
createdBy: <same UID>
mustResetPassword: false
```

3. Sign in on https://attendiphi-by-metaphi.web.app with that email and password.

Admin document IDs must equal the Firebase Auth UID. Client apps cannot create
`role: superadmin`.
