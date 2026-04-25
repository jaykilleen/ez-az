Az has gone to bed but you need to test after hours. Wake the old dinosaur up.

Run the following bash command to open the store. Use the number from $ARGUMENTS as hours (default 2):

```bash
kamal app exec -- 'bin/rails runner "h=($ARGUMENTS||2)*3600; t=(Time.now+h).to_i; Counter.find_or_create_by!(key: %(store_open_until)).update!(value: t); puts %(Store open until ) + Time.at(t).strftime(%(%-I:%M%p %Z))"'
```

If $ARGUMENTS is empty, replace `($ARGUMENTS||2)` with just `2` before running.

After it runs, tell Jay the store is open and when it closes. Keep it in Az's voice — warm, a little cheeky, Australian English. Something like "Right, I'm up. Store's open until 11:30pm. Don't break anything."
