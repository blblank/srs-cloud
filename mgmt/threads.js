'use strict';

const { Worker } = require("worker_threads");
const metadata = require('./metadata');

exports.run = async () => {
  new Promise((resolve, reject) => {
    const worker = new Worker("./releases.js");
    worker.on('message', (msg) => {
      metadata.releases = msg.metadata.releases;
    });
    worker.on('error', reject);
    worker.on('exit', (code) => {
      console.log(`thread #releases: exit with ${code}`);
      if (code !== 0) {
        return reject(new Error(`Worker #releases: stopped with exit code ${code}`));
      }
      resolve();
    });
  });

  new Promise((resolve, reject) => {
    const worker = new Worker("./crontab.js");
    worker.on('error', reject);
    worker.on('exit', (code) => {
      console.log(`thread #crontab: exit with ${code}`);
      if (code !== 0) {
        return reject(new Error(`Worker #crontab: stopped with exit code ${code}`));
      }
      resolve();
    });
  });

  if (process.env.USE_DOCKER === 'false') {
    console.warn(`run without docker, please start components by npm start`);
    return;
  }

  new Promise((resolve, reject) => {
    const worker = new Worker("./market.js");
    worker.on('message', (msg) => {
      Object.keys(msg.metadata).map(e => {
        metadata.market[e].container = msg.metadata[e];
      });
      //console.log(`update metadata by ${JSON.stringify(msg)} to ${JSON.stringify(metadata)}`);
    });
    worker.on('error', reject);
    worker.on('exit', (code) => {
      console.log(`thread #market: exit with ${code}`);
      if (code !== 0) {
        return reject(new Error(`Worker #market: stopped with exit code ${code}`));
      }
      resolve();
    });
  });
};

