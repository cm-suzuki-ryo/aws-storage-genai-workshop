## Generate Mock Images

If our dataset has missing image examples we can generate our own to help later test
the edge cases for our application.

We are using `Amazon Nova Canvas` to generate images.

```sh
./bin/generate
```

This will output a file to `010__prepare_dataset/outputs/images/`

<img src="../docs/assets/generated_image_1.png" width="600px"></img>

> Example of generated image using the following prompt: The image shows the eaves of a building with visible cracks, spalling, and missing components. The surface appears deteriorated, with signs of water damage and discoloration. The eaves are part of the building's exterior, and the defects are concentrated along the edge where the roof meets the wall.


## Annotate Images

We need to generate out annotation (metadata) information so we can search our iamgs.

We are using `Amazon Nova Pro` to to analyze the image.

The challenge is generated structured json output.
While this implementation of `./bin/annotate` works, there is a chance for 1,000 of runs it might fail and so more work need to put to catch edgecases.

```sh
./bin/annotate
```

Here is a example of annoation output: [annotate.json.example](./outputs/annotate.json.example)

> This will annotate our real images, not the mock ones. If we can to include the mock ones we need to copy them into the input directory

## Create Archive, Inventory File and Upload to S3

1. Zip our images to an archive
2. Read the zip file and create an inventory file with byte ranges for exact files
3. Upload the zip archive to our S3 bucket

```sh
./bin/upload
```

## Test Downloading Single Image from the Archive

This script will read the inventory file to get the byte range,
we will use the byte range to download the image from inside the archive.

We have to decompress the partial data to get to the final file.

```sh
./bin/download hk0155.jpg
```

## Create Embedding Data

We will use an embedding model to convert our annotation data int vector embeddings.
We'll generate out a SQL file to mass import our data into our database.

```sh
./bin/embedd
```