#!/bin/bash
HOSTNAME=$(hostname)
TEXTFILE_COLLECTOR_DIR=/var/lib/prometheus/node-exporter
FINAL_FNAME=ses_metrics.prom
OUTPUT_FNAME=$(mktemp /tmp/enc-output.XXXXXX)

lsscsi -g | grep NETAPP | while IFS= read -r line; do
  SESID=sg$(echo $line | grep -Po '\/dev\/sg\K(\d+)')
  SESDEV=/dev/$SESID
  FNAME=$(mktemp /tmp/enc-stat-$SESID.XXXXXX)

  sg_ses --page=all -HHHH $SESDEV > $FNAME

  for idx in $(seq 0 7); do
    volt=$(sg_ses --data=@$FNAME --status --page=es --index=6,$idx | grep Voltage | awk '{print $2}')
    echo "netapp_volt{host=\"$HOSTNAME\",dev=\"$SESDEV\",index=\"$idx\"} ${volt:-0}" >> $OUTPUT_FNAME
  done;
  
  for idx in $(seq 0 7); do
    current=$(sg_ses --data=@$FNAME --status --page=es --index=7,$idx | grep Current | awk '{print $2}')
    echo "netapp_amp{host=\"$HOSTNAME\",dev=\"$SESDEV\",index=\"$idx\"} ${current:-0}" >> $OUTPUT_FNAME
  done;
  
  for idx in $(seq 0 7); do
    volt=$(sg_ses --data=@$FNAME --status --page=es --index=6,$idx | grep Voltage | awk '{print $2}')
    current=$(sg_ses --data=@$FNAME --status --page=es --index=7,$idx | grep Current | awk '{print $2}')
    watt=$(echo "$volt * $current" | bc -l)
    echo "netapp_watt{host=\"$HOSTNAME\",dev=\"$SESDEV\",index=\"$idx\"} ${watt:-0}" >> $OUTPUT_FNAME
  done;
  
  for idx in $(seq 0 11); do
    temp=$(sg_ses --data=@$FNAME --status --page=es --index=3,$idx | grep -Po 'Temperature=\K(\d+)')
    echo "netapp_temp{host=\"$HOSTNAME\",dev=\"$SESDEV\",index=\"$idx\"} ${temp:-0}" >> $OUTPUT_FNAME
  done;
  
  for idx in $(seq 0 7); do
    rpm=$(sg_ses --data=@$FNAME --status --page=es --index=2,$idx | grep -Po 'Actual speed=\K(\d+)(?= rpm)')
    echo "netapp_rpm{host=\"$HOSTNAME\",dev=\"$SESDEV\",index=\"$idx\"} ${rpm:-0}" >> $OUTPUT_FNAME
  done;

  rm "$FNAME"
done;

echo "# HELP netapp_volt the netapp_volt" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# TYPE netapp_volt gauge" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
grep netapp_volt $OUTPUT_FNAME >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# HELP netapp_amp the netapp_volt" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# TYPE netapp_amp gauge" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
grep netapp_amp $OUTPUT_FNAME >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# HELP netapp_watt the netapp_volt" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# TYPE netapp_watt gauge" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
grep netapp_watt $OUTPUT_FNAME >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# HELP netapp_temp the netapp_volt" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# TYPE netapp_temp gauge" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
grep netapp_temp $OUTPUT_FNAME >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# HELP netapp_rpm the netapp_volt" >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
echo "# TYPE netapp_rpm gauge" >> $TEXTFILE_COLLECTOR_DIR/$FINALOUTPUT_FNAME.tmp
grep netapp_rpm $OUTPUT_FNAME >> $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp
  
mv $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME.tmp $TEXTFILE_COLLECTOR_DIR/$FINAL_FNAME
rm $OUTPUT_FNAME
