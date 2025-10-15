# Use an official Node.js runtime as a parent image
FROM node:alpine

# Set the working directory in the container
WORKDIR /usr/src/app
 
# Copy package.json and install dependencies
COPY package*.json ./
 
RUN npm install
 
# Copy the rest of the application code
COPY . .

# Expose the application port 
EXPOSE 3000
 
# Start the application
CMD ["node","index.js"]
